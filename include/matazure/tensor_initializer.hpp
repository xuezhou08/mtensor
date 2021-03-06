#pragma once

#include <initializer_list>
#include <matazure/point.hpp>
#include <vector>

namespace matazure {

template <typename _ValueType, int_t _Rank>
struct nested_initializer_list {
    using type =
        std::initializer_list<typename nested_initializer_list<_ValueType, _Rank - 1>::type>;

    static _ValueType access(const type& init, pointi<_Rank> idx) {
        auto tmp_i = idx[_Rank - 1];
        auto& sub_init = *(init.begin() + tmp_i);
        return nested_initializer_list<_ValueType, _Rank - 1>::access(sub_init,
                                                                      slice_point<_Rank - 1>(idx));
    }

    static pointi<_Rank> shape(const type& init) {
        return cat_point<_Rank - 1>(
            nested_initializer_list<_ValueType, _Rank - 1>::shape(*init.begin()),
            static_cast<int_t>(init.size()));
    };
};

template <typename _ValueType>
struct nested_initializer_list<_ValueType, 1> {
    using type = std::initializer_list<_ValueType>;

    static _ValueType access(const type& init, pointi<1> idx) { return *(init.begin() + idx[0]); }
    static pointi<1> shape(const type& init) { return pointi<1>{static_cast<int_t>(init.size())}; };
};

template <typename _ValueType, int_t _Rank>
_ValueType array_index_access(const nested_initializer_list<_ValueType, _Rank>& init,
                              pointi<_Rank> idx) {}

template <typename _ValueType>
_ValueType array_index_access(const nested_initializer_list<_ValueType, 1>& init, pointi<1> idx) {}

}  // namespace matazure
