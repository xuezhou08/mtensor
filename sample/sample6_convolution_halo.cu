#include <mtensor.hpp>
#include "image_helper.hpp"

using namespace matazure;

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "sample6_convolution input_image" << std::endl;
        return -1;
    }

    tensor<pointb<3>, 2> img_rgb = read_rgb_image(argv[1]);
    tensor<pointf<3>, 2> kernel_mean(pointi<2>{3, 3});
    fill(kernel_mean, pointf<3>{0.111f, 0.111f, 0.111f});

    cuda::tensor<pointb<3>, 2> cimg_rgb(img_rgb.shape());
    mem_copy(img_rgb, cimg_rgb);
    cuda::tensor<pointf<3>, 2> ckernel_mean(kernel_mean.shape());
    mem_copy(kernel_mean, ckernel_mean);

    typedef dim<16, 16> BLOCK_DIM;
    pointi<2> block_dim = BLOCK_DIM::value();
    auto grid_dim = (img_rgb.shape() + block_dim - pointi<2>{1, 1}) / block_dim;
    auto padding = kernel_mean.shape() / 2;

    cuda::tensor<pointf<3>, 2> cimg_mean(img_rgb.shape());

    cuda::block_for_index<BLOCK_DIM>(grid_dim, [=] __device__(
                                                   cuda::block_index<BLOCK_DIM> block_idx) {
        __shared__ local_tensor<pointf<3>, BLOCK_DIM> sh_ts_block;

        if (inside_rect(block_idx.global, pointi<2>{0, 0}, cimg_rgb.shape())) {
            sh_ts_block(block_idx.local) = point_cast<float>(cimg_rgb(block_idx.global));
        } else {
            sh_ts_block(block_idx.local) = pointf<3>{0, 0, 0};
        }

        cuda::sync_threads();

        if (inside_rect(block_idx.local, padding, block_idx.block_dim - ckernel_mean.shape() + 1) &&
            inside_rect(block_idx.global, pointi<2>{0, 0}, cimg_rgb.shape())) {
            auto sum = pointf<3>{0, 0, 0};
            for_index(pointi<2>{0, 0}, ckernel_mean.shape(), [&](const pointi<2>& idx) {
                sum += sh_ts_block(block_idx.local + idx - padding) * ckernel_mean(idx);
            });
            cimg_mean[block_idx.global] = sum;
        }
    });

    cuda::tensor<pointb<3>, 2> cimg_mean_byte(cimg_mean.shape());
    cuda::transform(cimg_mean, cimg_mean_byte,
                    [] __device__(pointf<3> pixel) { return point_cast<byte>(pixel); });

    tensor<pointb<3>, 2> img_mean(cimg_mean_byte.shape());
    mem_copy(cimg_mean_byte, img_mean);

    write_rgb_png("mean_" + std::string(argv[1]), img_mean);

    return 0;
}
