set(bm_cuda_src
    bm_main.cu
    bm_binary_operator.cu
    bm_for_index.cu
    bm_algorithm.cu
    bm_view.cu
    bm_execution_policy.cu
    bm_mem_copy.cu
    bm_conv.cu
    bm_block_for_index.cu
    bm_matrix_mul.cu
)

set(WITH_TENSORCORE ON)
if (WITH_TENSORCORE)
    list(APPEND bm_cuda_src bm_tensor_core.cu)
endif()

add_executable(bm_cuda_mtensor 
${bm_cuda_src}
)
target_link_libraries(bm_cuda_mtensor mtensor benchmark)
