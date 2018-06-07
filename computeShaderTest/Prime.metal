//
//  Prime.metal
//  computeShaderTest
//
//  Created by StellarBiblos on 2018/05/29.
//  Copyright © 2018年 StellarBiblos. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void calcPrimeNum (const device int *input [[buffer(0)]], // 計算対象数 (1~inpu+1まで)
                          device bool *primes [[buffer(1)]], // 出力先
                          uint id [[thread_position_in_grid]]) {
    int in = id+1;
    if (in == 1) {
        primes[id] = false;
        return;
    }
    else if (in == 2) {
        primes[id] = true;
        return;
    }
    
    if (in % 2 != 0) {
        for (int i = 3; i < in/2; i++) {
            if (in % i == 0) {
                primes[id] = false;
                return;
            }
        }
        primes[id] = true;
    }
}
