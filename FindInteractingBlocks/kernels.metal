//
//  Kernels.metal
//  OpenMMBenchmarks
//
//  Created by Philip Turner on 1/20/23.
//

#include <metal_stdlib>
using namespace metal;

constant uint NUM_BLOCKS [[function_constant(0)]];
constant uint NUM_ATOMS [[function_constant(1)]];
constant float PADDED_CUTOFF [[function_constant(2)]];
constant float PADDED_CUTOFF_SQUARED [[function_constant(3)]];

#define GROUP_SIZE 256
#define BUFFER_SIZE 256
#define TILE_SIZE 32

#define real2 float2
#define real3 float3
#define real4 float4

kernel void findBlocksWithInteractions(
    device atomic_uint* interactionCount,
    device int* interactingTiles,
    device unsigned int* interactingAtoms,
    device const float4* posq,
    constant unsigned int &maxTiles,
    constant unsigned int &startBlockIndex,
    constant unsigned int &numBlocks,
    device float2* sortedBlocks,
    device const float4* sortedBlockCenter,
    device const float4* sortedBlockBoundingBox,
    device float4* oldPositions,
    uint simd_lane_id [[thread_index_in_simdgroup]],
    uint simd_id [[simdgroup_index_in_threadgroup]],
    uint simds_per_tg [[simdgroups_per_threadgroup]],
    uint tg_lane_id [[thread_position_in_threadgroup]],
    uint tg_size [[threads_per_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tid [[thread_position_in_grid]],
    uint grid_size [[threads_per_grid]]) {

    const int indexInWarp = simd_lane_id;
    const int warpStart = simd_id * 32;
    const int totalWarps = grid_size / 32;
    const int warpIndex = tgid * simds_per_tg + simd_id;
    threadgroup int workgroupBuffer[BUFFER_SIZE*(GROUP_SIZE/32)];
    threadgroup float3 posBuffer[GROUP_SIZE];
    threadgroup volatile unsigned int workgroupTileIndex[GROUP_SIZE/32];
//    threadgroup bool includeBlockFlags[GROUP_SIZE];
    threadgroup volatile short2 atomCountBuffer[GROUP_SIZE];
    threadgroup int* buffer = workgroupBuffer+BUFFER_SIZE*(warpStart/32);
    threadgroup volatile unsigned int* tileStartIndex = workgroupTileIndex+(warpStart/32);

    // Loop over blocks.

    for (int block1 = startBlockIndex+warpIndex; block1 < int(startBlockIndex+numBlocks); block1 += totalWarps) {
        // Load data for this block.  Note that all threads in a warp are processing the same block.
        
        real2 sortedKey = sortedBlocks[block1];
        int x = (int) sortedKey.y;
        real4 blockCenterX = sortedBlockCenter[block1];
        real4 blockSizeX = sortedBlockBoundingBox[block1];
        int neighborsInBuffer = 0;
        real3 pos1 = posq[x*TILE_SIZE+indexInWarp].xyz;
        posBuffer[tg_lane_id] = pos1;

        // Load exclusion data for block x.
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        // Loop over atom blocks to search for neighbors.  The threads in a warp compare block1 against 32
        // other blocks in parallel.

        for (int block2Base = block1+1; block2Base < int(NUM_BLOCKS); block2Base += 32) {
//            int block2 = block2Base+indexInWarp;
//            bool includeBlock2 = (block2 < int(NUM_BLOCKS));
//            if (includeBlock2) {
//                real4 blockCenterY = sortedBlockCenter[block2];
//                real4 blockSizeY = sortedBlockBoundingBox[block2];
//                real4 blockDelta = blockCenterX-blockCenterY;
//                includeBlock2 &= (blockDelta.x*blockDelta.x+blockDelta.y*blockDelta.y+blockDelta.z*blockDelta.z < (PADDED_CUTOFF+blockCenterX.w+blockCenterY.w)*(PADDED_CUTOFF+blockCenterX.w+blockCenterY.w));
//                blockDelta.x = max(float(0), fabs(blockDelta.x)-blockSizeX.x-blockSizeY.x);
//                blockDelta.y = max(float(0), fabs(blockDelta.y)-blockSizeX.y-blockSizeY.y);
//                blockDelta.z = max(float(0), fabs(blockDelta.z)-blockSizeX.z-blockSizeY.z);
//                includeBlock2 &= (blockDelta.x*blockDelta.x+blockDelta.y*blockDelta.y+blockDelta.z*blockDelta.z < PADDED_CUTOFF_SQUARED);
//            }
            
            // Loop over any blocks we identified as potentially containing neighbors.
            
//            includeBlockFlags[tg_lane_id] = includeBlock2;
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (int i = 0; i < TILE_SIZE; i++) {
//                while (i < TILE_SIZE && !includeBlockFlags[warpStart+i])
//                    i++;
                if (i < TILE_SIZE) {
                    int y = (int) sortedBlocks[block2Base+i].y;

                    // Check each atom in block Y for interactions.

                    int atom2 = y*TILE_SIZE+indexInWarp;
                    real3 pos2 = posq[atom2].xyz;
                    bool interacts = false;
                    if (atom2 < int(NUM_ATOMS)) {
                            for (int j = 0; j < TILE_SIZE; j++) {
                                real3 delta = pos2-posBuffer[warpStart+j];
                                interacts |= (delta.x*delta.x+delta.y*delta.y+delta.z*delta.z < PADDED_CUTOFF_SQUARED);
                            }
                    }
                    
                    // Do a prefix sum to compact the list of atoms.

                    atomCountBuffer[tg_lane_id].x = (interacts ? 1 : 0);
                    threadgroup_barrier(mem_flags::mem_threadgroup);
                    int whichBuffer = 0;
                    for (int offset = 1; offset < TILE_SIZE; offset *= 2) {
                        if (whichBuffer == 0)
                            atomCountBuffer[tg_lane_id].y = (indexInWarp < offset ? atomCountBuffer[tg_lane_id].x : atomCountBuffer[tg_lane_id].x+atomCountBuffer[tg_lane_id-offset].x);
                        else
                            atomCountBuffer[tg_lane_id].x = (indexInWarp < offset ? atomCountBuffer[tg_lane_id].y : atomCountBuffer[tg_lane_id].y+atomCountBuffer[tg_lane_id-offset].y);
                        whichBuffer = 1-whichBuffer;
                        threadgroup_barrier(mem_flags::mem_threadgroup);
                    }
                    
                    // Add any interacting atoms to the buffer.

                    if (interacts)
                        buffer[neighborsInBuffer+atomCountBuffer[tg_lane_id].y-1] = atom2;
                    neighborsInBuffer += atomCountBuffer[warpStart+TILE_SIZE-1].y;
//                    if (neighborsInBuffer > BUFFER_SIZE-TILE_SIZE) {
//                        // Store the new tiles to memory.
//
//                        unsigned int tilesToStore = neighborsInBuffer/TILE_SIZE;
//                        if (indexInWarp == 0)
//                            *tileStartIndex = atomic_fetch_add_explicit(interactionCount, tilesToStore, memory_order_relaxed);
//                        threadgroup_barrier(mem_flags::mem_threadgroup);
//                        unsigned int newTileStartIndex = *tileStartIndex;
//                        if (newTileStartIndex+tilesToStore <= maxTiles) {
//                            if (indexInWarp < int(tilesToStore))
//                                interactingTiles[newTileStartIndex+indexInWarp] = x;
//                            for (int j = 0; j < int(tilesToStore); j++)
//                                interactingAtoms[(newTileStartIndex+j)*TILE_SIZE+indexInWarp] = buffer[indexInWarp+j*TILE_SIZE];
//                        }
//                        if (indexInWarp+TILE_SIZE*tilesToStore < BUFFER_SIZE)
//                            buffer[indexInWarp] = buffer[indexInWarp+TILE_SIZE*tilesToStore];
//                        neighborsInBuffer -= TILE_SIZE*tilesToStore;
//                   }
                }
                else {
                    threadgroup_barrier(mem_flags::mem_threadgroup);
                }
            }
        }
        
        // If we have a partially filled buffer,  store it to memory.
        
//        if (neighborsInBuffer > 0) {
//            unsigned int tilesToStore = (neighborsInBuffer+TILE_SIZE-1)/TILE_SIZE;
//            if (indexInWarp == 0)
//                *tileStartIndex = atomic_fetch_add_explicit(interactionCount, tilesToStore, memory_order_relaxed);
//            threadgroup_barrier(mem_flags::mem_threadgroup);
//            unsigned int newTileStartIndex = *tileStartIndex;
//            if (newTileStartIndex+tilesToStore <= maxTiles) {
//                if (indexInWarp < int(tilesToStore))
//                    interactingTiles[newTileStartIndex+indexInWarp] = x;
//                for (int j = 0; j < int(tilesToStore); j++)
//                    interactingAtoms[(newTileStartIndex+j)*TILE_SIZE+indexInWarp] = (indexInWarp+j*TILE_SIZE < neighborsInBuffer ? buffer[indexInWarp+j*TILE_SIZE] : NUM_ATOMS);
//            }
//        }
    }
    
    // Record the positions the neighbor list is based on.
    
    for (int i = tid; i < int(NUM_ATOMS); i += grid_size)
        oldPositions[i] = posq[i];
}
