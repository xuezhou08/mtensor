#include "../bm_view.hpp"

auto bm_cuda_tensor2f_view_crop = bm_tensor_crop<cuda::tensor<float, 2>>;
BENCHMARK(bm_cuda_tensor2f_view_crop)->Arg(32_K);

auto bm_cuda_tensor2f_view_stride = bm_tensor_stride<cuda::tensor<float, 2>>;
BENCHMARK(bm_cuda_tensor2f_view_stride)->Arg(32_K);
