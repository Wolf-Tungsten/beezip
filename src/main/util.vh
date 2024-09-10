`ifndef UTIL_VH
`define UTIL_VH

`define TD #1

`define ZERO_EXTEND(input, width) {{(width)-$bits(input){1'b0}}, (input)}
`define SIGN_EXTEND(input, width) {{(width)-$bits(input){(input)[$bits(input)-1]}}, (input)}
`define VEC_SLICE(vec, idx, width) {vec[(idx)*(width) +: (width)]}

`endif
