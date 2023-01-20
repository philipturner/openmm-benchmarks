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

// 1536 threads/core is fastest
// threadgroupSize = 256 is fastest
// With these parameters, based config gets 25573 us (M1 Max).
// With matrix multiplication instead: 26322 us.
// With matrix multiplication + half precision: 26563 us.
// With matrix multiplication + half precision + SIMD broadcast: 40780 us.
// With matrix multiplication + half precision, switching to SIMD prefix inclusive sum: 18697 us.
// With matrix multiplication, switching to SIMD prefix inclusive sum: 22519 us.
// Force unroll the loop: 16169 us.
// Add half precision: 15501 us.
// Add BFloat16: 25199 us.
// Single precision, not switching to SIMD prefix inclusive sum: 23219 us.

// No matrix multiplication, switching to SIMD prefix inclusive sum: 22661 us.
// Force unroll the loop: 17337 us.
// Single precision, not switching to SIMD prefix inclusive sum: 21559 us.

// Determine whether SIMD shuffle helps.
// Determine whether simdgroup_matrix helps.
// Determine whether half precision helps.
// Determine whether BFloat16 packing helps.
#define MATRIX_MULTIPLICATION 1

#define GROUP_SIZE 256
#define BUFFER_SIZE 256
#define TILE_SIZE 32

#define real2 float2
#define real3 float3
#define real4 float4

ushort pack(float x) {
    return as_type<ushort2>(x)[1];
}
ushort4 pack(float4 x) {
    return ushort4(pack(x[0]), pack(x[1]), pack(x[2]), pack(x[3]));
}
float unpack(ushort x) {
    return as_type<float>(ushort2(0, x));
}
float4 unpack(ushort4 x) {
    return float4(unpack(x[0]), unpack(x[1]), unpack(x[2]), unpack(x[3]));
}

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
#if MATRIX_MULTIPLICATION
    threadgroup float4 posBuffer[GROUP_SIZE];
#else
    threadgroup float3 posBuffer[GROUP_SIZE];
#endif
    threadgroup volatile short2 atomCountBuffer[GROUP_SIZE];

    // Loop over blocks.

    for (int block1 = warpIndex; block1 < int(NUM_BLOCKS); block1 += totalWarps) {
        // Load data for this block.  Note that all threads in a warp are processing the same block.
        
        int x = sortedBlocks[(block1) % 128].y;
        int neighborsInBuffer = 0;
#if MATRIX_MULTIPLICATION
        real4 pos1 = posq[(x*TILE_SIZE+indexInWarp) % 128];
        pos1.w = 0.5f * (pos1.x * pos1.x + pos1.y * pos1.y + pos1.z * pos1.z);
        posBuffer[tg_lane_id] = float4(pos1);
#else
        real3 pos1 = posq[(x*TILE_SIZE+indexInWarp) % 128].xyz;
        posBuffer[tg_lane_id] = pos1;
#endif
        
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
#if MATRIX_MULTIPLICATION
                real4 pos2 = posq[(atom2) % 128];
                bool interacts = false;
                if (atom2 < int(NUM_ATOMS)) {
                
#define LOOP_BLOCK(j) \
{\
                        float4 posj = (posBuffer[warpStart+j]);\
                        float halfDist2 = posj.w + pos2.w - posj.x*pos2.x - posj.y*pos2.y - posj.z*pos2.z;\
                        interacts |= (halfDist2 < 0.5f * PADDED_CUTOFF_SQUARED);\
}\

#define LOOP_BLOCK_4(Q) \
LOOP_BLOCK(Q+0) \
LOOP_BLOCK(Q+1) \
LOOP_BLOCK(Q+2) \
LOOP_BLOCK(Q+3) \

                LOOP_BLOCK_4(0);
                LOOP_BLOCK_4(4);
                LOOP_BLOCK_4(8);
                LOOP_BLOCK_4(12);
                LOOP_BLOCK_4(16);
                LOOP_BLOCK_4(20);
                LOOP_BLOCK_4(24);
                LOOP_BLOCK_4(28);

                
//                    for (int j = 0; j < TILE_SIZE; j++) {
//                        float4 posj = posBuffer[warpStart+j];
//                        float halfDist2 = posj.w + pos2.w - posj.x*pos2.x - posj.y*pos2.y - posj.z*pos2.z;
//                        interacts |= (halfDist2 < 0.5f * PADDED_CUTOFF_SQUARED);
//                    }
                }
#else
                real3 pos2 = posq[(atom2) % 128].xyz;
                bool interacts = false;
                if (atom2 < int(NUM_ATOMS)) {
#define LOOP_BLOCK(j) \
{\
                        real3 delta = pos2-posBuffer[warpStart+j];\
                        interacts |= (delta.x*delta.x+delta.y*delta.y+delta.z*delta.z < PADDED_CUTOFF_SQUARED);\
}\

#define LOOP_BLOCK_4(Q) \
LOOP_BLOCK(Q+0) \
LOOP_BLOCK(Q+1) \
LOOP_BLOCK(Q+2) \
LOOP_BLOCK(Q+3) \

                LOOP_BLOCK_4(0);
                LOOP_BLOCK_4(4);
                LOOP_BLOCK_4(8);
                LOOP_BLOCK_4(12);
                LOOP_BLOCK_4(16);
                LOOP_BLOCK_4(20);
                LOOP_BLOCK_4(24);
                LOOP_BLOCK_4(28);

                }
#endif
                
                // Do a prefix sum to compact the list of atoms.
                
                int toSum = (interacts ? 1 : 0);
                int prefixSum = simd_prefix_inclusive_sum(toSum);
                neighborsInBuffer += simd_broadcast(prefixSum, 31);

//                atomCountBuffer[tg_lane_id].x = (interacts ? 1 : 0);
//                threadgroup_barrier(mem_flags::mem_threadgroup);
//                int whichBuffer = 0;
//                for (int offset = 1; offset < TILE_SIZE; offset *= 2) {
//                    if (whichBuffer == 0)
//                        atomCountBuffer[tg_lane_id].y = (indexInWarp < offset ? atomCountBuffer[tg_lane_id].x : atomCountBuffer[tg_lane_id].x+atomCountBuffer[tg_lane_id-offset].x);
//                    else
//                        atomCountBuffer[tg_lane_id].x = (indexInWarp < offset ? atomCountBuffer[tg_lane_id].y : atomCountBuffer[tg_lane_id].y+atomCountBuffer[tg_lane_id-offset].y);
//                    whichBuffer = 1-whichBuffer;
//                    threadgroup_barrier(mem_flags::mem_threadgroup);
//                }
//
//                // Add any interacting atoms to the buffer.
//
//                neighborsInBuffer += atomCountBuffer[warpStart+TILE_SIZE-1].y;
            }
        }
        return_neighborsInBuffer[0] = neighborsInBuffer;
    }
}
