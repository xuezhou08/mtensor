#include "../bm_conv.hpp"

auto bm_cuda_tensor2f_general_roll_conv = bm_tensor_general_roll_conv<cuda::tensor<float, 2>>;
BENCHMARK(bm_cuda_tensor2f_general_roll_conv)->Arg(512)->Arg(1_K)->Arg(10_K);

auto bm_cuda_tensor2f_general_unroll_conv = bm_tensor_general_unroll_conv<cuda::tensor<float, 2>>;
BENCHMARK(bm_cuda_tensor2f_general_unroll_conv)->Arg(512)->Arg(1_K)->Arg(2_K)->Arg(10_K);

static void bm_cuda_tensor_block_conv_halo(benchmark::State& state) {
    pointi<2> grid_dim;
    fill(grid_dim, state.range(0));

    typedef dim<16, 16> BLOCK_DIM;
    pointi<2> block_dim = BLOCK_DIM::value();

    auto shape = block_dim * grid_dim;

    cuda::tensor<float, 2> ts_src(shape);
    cuda::tensor<float, 2> ts_dst(ts_src.shape());

    cuda::tensor<float, 2> ts_kernel(pointi<2>{3, 3});
    auto padding = ts_kernel.shape() / 2;

    while (state.KeepRunning()) {
        cuda::block_for_index<BLOCK_DIM>(grid_dim, [=] __device__(
                                                       cuda::block_index<BLOCK_DIM> block_idx) {
            //  使用shared memory以获取更好的速度
            __shared__ local_tensor<float, BLOCK_DIM> sh_ts_block;
            //  若是无效区域则填充0
            sh_ts_block(block_idx.local) = static_cast<float>(ts_src(block_idx.global));
            cuda::syncthreads();

            if (inside_rect(block_idx.local, padding,
                            block_idx.block_dim - ts_kernel.shape() + 1) &&
                inside_rect(block_idx.global, pointi<2>{0, 0}, ts_src.shape())) {
                auto re = 0.0f;
                re += ts_kernel(pointi<2>{0, 0}) * sh_ts_block(block_idx.local + pointi<2>{-1, -1});
                re += ts_kernel(pointi<2>{1, 0}) * sh_ts_block(block_idx.local + pointi<2>{0, -1});
                re += ts_kernel(pointi<2>{2, 0}) * sh_ts_block(block_idx.local + pointi<2>{1, -1});
                re += ts_kernel(pointi<2>{0, 1}) * sh_ts_block(block_idx.local + pointi<2>{-1, 0});
                re += ts_kernel(pointi<2>{1, 1}) * sh_ts_block(block_idx.local + pointi<2>{0, 0});
                re += ts_kernel(pointi<2>{2, 1}) * sh_ts_block(block_idx.local + pointi<2>{1, 0});
                re += ts_kernel(pointi<2>{0, 2}) * sh_ts_block(block_idx.local + pointi<2>{-1, 1});
                re += ts_kernel(pointi<2>{1, 2}) * sh_ts_block(block_idx.local + pointi<2>{0, 1});
                re += ts_kernel(pointi<2>{2, 2}) * sh_ts_block(block_idx.local + pointi<2>{1, 1});
                ts_dst(block_idx.global) = re;
            }
        });
    }

    state.SetBytesProcessed(state.iterations() * static_cast<size_t>(ts_src.size()) *
                            sizeof(ts_dst[0]));
    state.SetItemsProcessed(state.iterations() * static_cast<size_t>(ts_src.size()) *
                            ts_kernel.size() * 2);
}

BENCHMARK(bm_cuda_tensor_block_conv_halo)->Arg(1_K)->Arg(2_K);

static void bm_cuda_tensor_block_conv_overlap(benchmark::State& state) {
    pointi<2> grid_dim;
    fill(grid_dim, state.range(0));

    typedef dim<16, 16> BLOCK_DIM;
    pointi<2> block_dim = BLOCK_DIM::value();

    cuda::tensor<float, 2> ts_kernel(pointi<2>{3, 3});
    auto padding = ts_kernel.shape() / 2;

    auto valid_block_dim = block_dim - ts_kernel.shape() + 1;

    auto shape = valid_block_dim * grid_dim;

    cuda::tensor<float, 2> ts_src(shape);
    cuda::tensor<float, 2> ts_dst(ts_src.shape());

    while (state.KeepRunning()) {
        cuda::block_for_index<BLOCK_DIM>(grid_dim, [=] __device__(
                                                       cuda::block_index<BLOCK_DIM> block_idx) {

            auto valid_global_idx = valid_block_dim * block_idx.block + block_idx.local - padding;
            __shared__ local_tensor<float, BLOCK_DIM> sh_ts_block;

            if (inside_rect(valid_global_idx, pointi<2>{0, 0}, ts_src.shape())) {
                sh_ts_block(block_idx.local) = ts_src(valid_global_idx);
            } else {
                sh_ts_block(block_idx.local) = 0.0f;
            }

            cuda::syncthreads();

            if (inside_rect(block_idx.local, padding,
                            block_idx.block_dim - ts_kernel.shape() + pointi<2>{1, 1}) &&
                inside_rect(valid_global_idx, zero<pointi<2>>::value(), ts_src.shape())) {
                auto re = 0.0f;
                re += ts_kernel(pointi<2>{0, 0}) * sh_ts_block(block_idx.local + pointi<2>{-1, -1});
                re += ts_kernel(pointi<2>{1, 0}) * sh_ts_block(block_idx.local + pointi<2>{0, -1});
                re += ts_kernel(pointi<2>{2, 0}) * sh_ts_block(block_idx.local + pointi<2>{1, -1});
                re += ts_kernel(pointi<2>{0, 1}) * sh_ts_block(block_idx.local + pointi<2>{-1, 0});
                re += ts_kernel(pointi<2>{1, 1}) * sh_ts_block(block_idx.local + pointi<2>{0, 0});
                re += ts_kernel(pointi<2>{2, 1}) * sh_ts_block(block_idx.local + pointi<2>{1, 0});
                re += ts_kernel(pointi<2>{0, 2}) * sh_ts_block(block_idx.local + pointi<2>{-1, 1});
                re += ts_kernel(pointi<2>{1, 2}) * sh_ts_block(block_idx.local + pointi<2>{0, 1});
                re += ts_kernel(pointi<2>{2, 2}) * sh_ts_block(block_idx.local + pointi<2>{1, 1});
                ts_dst(valid_global_idx) = re;
            }
        });
    }

    state.SetBytesProcessed(state.iterations() * static_cast<size_t>(ts_src.size()) *
                            sizeof(ts_dst[0]));
    state.SetItemsProcessed(state.iterations() * static_cast<size_t>(ts_src.size()) *
                            ts_kernel.size() * 2);
}

BENCHMARK(bm_cuda_tensor_block_conv_overlap)->Arg(1_K)->Arg(1500);