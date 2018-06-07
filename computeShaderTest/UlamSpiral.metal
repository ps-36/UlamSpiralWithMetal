//
//  UlamSpiral.metal
//  computeShaderTest
//
//  Created by StellarBiblos on 2018/05/30.
//  Copyright © 2018年 StellarBiblos. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

uint circle (int n) {
    int sigma = 0;
    for (int i=n; i>0; i--) {
        sigma += 8*i;
    }
    return uint(sigma - 4*n);
}

struct ColorInOut {
    float4 position [[position]];
    float2 texCoords;
    bool primes;
};

vertex ColorInOut vertex_passthrough (device float4 *position [[buffer(0)]],
                                      device float2 *texCoords [[buffer(1)]],
                                      device bool *primes [[buffer(2)]],
                                      uint vid [[vertex_id]]){
    ColorInOut out;
    out.position = position[vid];
    out.texCoords = texCoords[vid];
    out.primes = primes[vid];
    return out;
}

//螺旋に変換済みであれば使う
//今回は使っていない
kernel void plot_compute (device bool *primes [[buffer(0)]],
                          device int *size [[buffer(1)]], //[0] = width, [1] = height
                          texture2d<float, access::write> texture [[texture(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    float4 color;
    int index = gid[0] * size[0] + gid[1];
    if (primes[index]) {
        color = float4(0,0,0,1);
    }
    else {
        color = float4(1,1,1,1);
    }
    texture.write(color, gid);
}

// 配列から螺旋へマップして直接textureへ吐き出す
// 面倒だったから一辺は偶数,primesはその2乗を前提に
// n回螺旋を描くに必要な自然数の合計 = Σ8n - 4n
kernel void circle_prime (device bool *primes [[buffer(0)]],
                          device uint *size [[buffer(1)]],
                          texture2d<float, access::write> texture [[texture(0)]],
                          uint2 gid [[thread_position_in_grid]]
                          ) {
    float4 color;
    uint primeIndex = 0;
    
    // nの判定
    int plx = (size[0]/2 < gid[0] ? 1 : -1);
    int ply = (size[0]/2 < gid[1] ? 1 : -1);
    int nx = gid[0] * plx - size[0]/2 * plx;
    int ny = gid[1] * ply - size[0]/2 * ply;
    int n = nx > ny ? nx : ny;
    
    if (gid[0] == size[1]/2-n && gid[1] <= size[0]/2 +n -2) { // ∑8(n-1) +1 <= index <= ∑8(n-1) + 2n-1
        primeIndex = circle(n-1) +size[0]/2+n - gid[1];
    }
    else if (gid[1] == size[0]/2-n && gid[0] <= size[0]/2 +n -2) { // ∑8(n-1) +2n <= index <= ∑8(n-1) + 4n-2
        primeIndex = circle(n-1)+2*n + gid[0]-(size[0]/2-n);
    }
    else if (gid[0] >= size[0]/2+n-1) { // ∑8(n-1) + 4n-1 <= index <= ∑8(n-1) + 6n-3
        primeIndex = circle(n-1) + 4*n-1 + gid[1] - (size[0]/2 -n);
    }
    else { // ∑8(n-1) + 6n-2 <= index <= ∑8n
        primeIndex = circle(n-1) + 6*n-2 +size[0]/2+n - gid[0];
    }
    
    if (primes[primeIndex-1]) {color = float4(0,0,0,1);}
    else { color = float4(1,1,1,1);}
    
    texture.write(color, gid);
}
