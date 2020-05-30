/*!
 *  Copyright (c) 2019 by Contributors
 * \file array/cuda/array_op_impl.cu
 * \brief Array operator GPU implementation
 */
#include <dgl/array.h>
#include "../../runtime/cuda/cuda_common.h"

namespace dgl {
using runtime::NDArray;
namespace aten {
namespace impl {

int FindNumThreads(int dim, int max_nthrs) {
  int ret = max_nthrs;
  while (ret > dim) {
    ret = ret >> 1;
  }
  return ret;
}

template <typename InType, typename OutType>
__global__ void _CastKernel(const InType* in, OutType* out, size_t length) {
  int tx = blockIdx.x * blockDim.x + threadIdx.x;
  int stride_x = gridDim.x * blockDim.x;
  while (tx < length) {
    out[tx] = in[tx];
    tx += stride_x;
  }
}

template <DLDeviceType XPU, typename IdType>
IdArray AsNumBits(IdArray arr, uint8_t bits) {
  const std::vector<int64_t> shape(arr->shape, arr->shape + arr->ndim);
  IdArray ret = IdArray::Empty(shape, DLDataType{kDLInt, bits, 1}, arr->ctx);
  const int64_t length = ret.Numel();
  auto* thr_entry = runtime::CUDAThreadEntry::ThreadLocal();
  int nt = FindNumThreads(length, 1024);
  int nb = (length + nt - 1) / nt;
  if (bits == 32) {
    _CastKernel<IdType, int32_t><<<nb, nt, 0, thr_entry->stream>>>(
        static_cast<IdType*>(arr->data), static_cast<int32_t*>(ret->data), length);
  } else {
    _CastKernel<IdType, int64_t><<<nb, nt, 0, thr_entry->stream>>>(
        static_cast<IdType*>(arr->data), static_cast<int64_t*>(ret->data), length);
  }
  return ret;
}


template IdArray AsNumBits<kDLGPU, int32_t>(IdArray arr, uint8_t bits);
template IdArray AsNumBits<kDLGPU, int64_t>(IdArray arr, uint8_t bits);

}  // namespace impl
}  // namespace aten
}  // namespace dgl
