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
constant float PADDED_CUTOFF_SQUARED = 1;

#define GROUP_SIZE 256
#define BUFFER_SIZE 256
#define TILE_SIZE 32

#define real2 float2
#define real3 float3
#define real4 float4

kernel void findBlocksWithInteractions(
    device const float4* posq,
    device int2* sortedBlocks,
    device uint *return_neighborsInBuffer,
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
    threadgroup float3 posBuffer[GROUP_SIZE];
    threadgroup volatile short2 atomCountBuffer[GROUP_SIZE];

    // Loop over blocks.

    for (int block1 = warpIndex; block1 < int(NUM_BLOCKS); block1 += totalWarps) {
        // Load data for this block.  Note that all threads in a warp are processing the same block.
        
        int x = sortedBlocks[(block1) % 128].y;
        int neighborsInBuffer = 0;
        real3 pos1 = posq[(x*TILE_SIZE+indexInWarp) % 128].xyz;
        posBuffer[tg_lane_id] = pos1;

        // Load exclusion data for block x.
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        // Loop over atom blocks to search for neighbors.  The threads in a warp compare block1 against 32
        // other blocks in parallel.

        for (int block2Base = block1+1; block2Base < int(NUM_BLOCKS); block2Base += 32) {
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (int i = 0; i < TILE_SIZE; i++) {
                // Check each atom in block Y for interactions.

                int y = sortedBlocks[(block2Base+i) % 128].y;
                int atom2 = y*TILE_SIZE+indexInWarp;
                real3 pos2 = posq[(atom2) % 128].xyz;
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

                neighborsInBuffer += atomCountBuffer[warpStart+TILE_SIZE-1].y;
            }
        }
        return_neighborsInBuffer[0] = neighborsInBuffer;
    }
}
