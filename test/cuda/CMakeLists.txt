
add_executable(ut_cuda_mtensor 
    main.cu
    ut_launch.cu
    ut_algorithm.cu
    ut_lambda_tensor.cu
    ut_execution_policy.cu
    ut_tensor.cu
    ut_nv_exe_check_disable.cu
)
target_link_libraries(ut_cuda_mtensor mtensor gtest)
