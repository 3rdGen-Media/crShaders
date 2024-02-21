/**
 * Copyright (c) 2017 Eric Bruneton
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Precomputed Atmospheric Scattering
 * Copyright (c) 2008 INRIA
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */


 /*<h2>atmosphere/functions.glsl</h2>

 <p>This GLSL file contains the core functions that implement our atmosphere
 model. It provides functions to compute the transmittance, the single scattering
 and the second and higher orders of scattering, the ground irradiance, as well
 as functions to store these in textures and to read them back. It uses physical
 types and constants which are provided in two versions: a
 <a href="definitions.glsl.html">GLSL version</a> and a
 <a href="reference/definitions.h.html">C++ version</a>. This allows this file to
 be compiled either with a GLSL compiler or with a C++ compiler (see the
 <a href="../index.html">Introduction</a>).

 <p>The functions provided in this file are organized as follows:
 <ul>
 <li><a href="#transmittance">Transmittance</a>
 <ul>
 <li><a href="#transmittance_computation">Computation</a></li>
 <li><a href="#transmittance_precomputation">Precomputation</a></li>
 <li><a href="#transmittance_lookup">Lookup</a></li>
 </ul>
 </li>
 <li><a href="#single_scattering">Single scattering</a>
 <ul>
 <li><a href="#single_scattering_computation">Computation</a></li>
 <li><a href="#single_scattering_precomputation">Precomputation</a></li>
 <li><a href="#single_scattering_lookup">Lookup</a></li>
 </ul>
 </li>
 <li><a href="#multiple_scattering">Multiple scattering</a>
 <ul>
 <li><a href="#multiple_scattering_computation">Computation</a></li>
 <li><a href="#multiple_scattering_precomputation">Precomputation</a></li>
 <li><a href="#multiple_scattering_lookup">Lookup</a></li>
 </ul>
 </li>
 <li><a href="#irradiance">Ground irradiance</a>
 <ul>
 <li><a href="#irradiance_computation">Computation</a></li>
 <li><a href="#irradiance_precomputation">Precomputation</a></li>
 <li><a href="#irradiance_lookup">Lookup</a></li>
 </ul>
 </li>
 <li><a href="#rendering">Rendering</a>
 <ul>
 <li><a href="#rendering_sky">Sky</a></li>
 <li><a href="#rendering_aerial_perspective">Aerial perspective</a></li>
 <li><a href="#rendering_ground">Ground</a></li>
 </ul>
 </li>
 </ul>

 <p>They use the following utility functions to avoid NaNs due to floating point
values slightly outside their theoretical bounds:
*/


Number ClampCosine(Number mu) {
	return clamp(mu, Number(-1.0), Number(1.0));
}

Length ClampDistance(Length d) {
	return max(d, 0.0 * m);
}

Length ClampRadius(IN(AtmosphereParameters) atmosphere, Length r) {
	return clamp(r, atmosphere.bottom_radius, atmosphere.top_radius);
}

Length SafeSqrt(Area a) {
	return sqrt(max(a, 0.0 * m2));
}


/*
<h3 id="transmittance">Transmittance</h3>

<p>As the light travels from a point $\bp$ to a point $\bq$ in the atmosphere,
it is partially absorbed and scattered out of its initial direction because of
the air molecules and the aerosol particles. Thus, the light arriving at $\bq$
is only a fraction of the light from $\bp$, and this fraction, which depends on
wavelength, is called the
<a href="https://en.wikipedia.org/wiki/Transmittance">transmittance</a>. The
following sections describe how we compute it, how we store it in a precomputed
texture, and how we read it back.

<h4 id="transmittance_computation">Computation</h4>

<p>For 3 aligned points $\bp$, $\bq$ and $\br$ inside the atmosphere, in this
order, the transmittance between $\bp$ and $\br$ is the product of the
transmittance between $\bp$ and $\bq$ and between $\bq$ and $\br$. In
particular, the transmittance between $\bp$ and $\bq$ is the transmittance
between $\bp$ and the nearest intersection $\bi$ of the half-line $[\bp,\bq)$
with the top or bottom atmosphere boundary, divided by the transmittance between
$\bq$ and $\bi$ (or 0 if the segment $[\bp,\bq]$ intersects the ground):

<svg width="340px" height="195px">
  <style type="text/css"><![CDATA[
    circle { fill: #000000; stroke: none; }
    path { fill: none; stroke: #000000; }
    text { font-size: 16px; font-style: normal; font-family: Sans; }
    .vector { font-weight: bold; }
  ]]></style>
  <path d="m 0,26 a 600,600 0 0 1 340,0"/>
  <path d="m 0,110 a 520,520 0 0 1 340,0"/>
  <path d="m 170,190 0,-30"/>
  <path d="m 170,140 0,-130"/>
  <path d="m 170,50 165,-33"/>
  <path d="m 155,150 10,-10 10,10 10,-10"/>
  <path d="m 155,160 10,-10 10,10 10,-10"/>
  <path d="m 95,50 30,0"/>
  <path d="m 95,190 30,0"/>
  <path d="m 105,50 0,140" style="stroke-dasharray:8,2;"/>
  <path d="m 100,55 5,-5 5,5"/>
  <path d="m 100,185 5,5 5,-5"/>
  <path d="m 170,25 a 25,25 0 0 1 25,20" style="stroke-dasharray:4,2;"/>
  <path d="m 170,190 70,0"/>
  <path d="m 235,185 5,5 -5,5"/>
  <path d="m 165,125 5,-5 5,5"/>
  <circle cx="170" cy="190" r="2.5"/>
  <circle cx="170" cy="50" r="2.5"/>
  <circle cx="320" cy="20" r="2.5"/>
  <circle cx="270" cy="30" r="2.5"/>
  <text x="155" y="45" class="vector">p</text>
  <text x="265" y="45" class="vector">q</text>
  <text x="320" y="15" class="vector">i</text>
  <text x="175" y="185" class="vector">o</text>
  <text x="90" y="125">r</text>
  <text x="185" y="25">mu=cos(theta)</text>
  <text x="240" y="185">x</text>
  <text x="155" y="120">z</text>
</svg>


<p>Also, the transmittance between $\bp$ and $\bq$ and between $\bq$ and $\bp$
are the same. Thus, to compute the transmittance between arbitrary points, it
is sufficient to know the transmittance between a point $\bp$ in the atmosphere,
and points $\bi$ on the top atmosphere boundary. This transmittance depends on
only two parameters, which can be taken as the radius $r=\Vert\bo\bp\Vert$ and
the cosine of the "view zenith angle",
$\mu=\bo\bp\cdot\bp\bi/\Vert\bo\bp\Vert\Vert\bp\bi\Vert$. To compute it, we
first need to compute the length $\Vert\bp\bi\Vert$, and we need to know when
the segment $[\bp,\bi]$ intersects the ground.

<h5>Distance to the top atmosphere boundary</h5>

<p>A point at distance $d$ from $\bp$ along $[\bp,\bi)$ has coordinates
$[d\sqrt{1-\mu^2}, r+d\mu]^\top$, whose squared norm is $d^2+2r\mu d+r^2$.
Thus, by definition of $\bi$, we have
$\Vert\bp\bi\Vert^2+2r\mu\Vert\bp\bi\Vert+r^2=r_{\mathrm{top}}^2$,
from which we deduce the length $\Vert\bp\bi\Vert$:
*/

Length DistanceToTopAtmosphereBoundary(IN(AtmosphereParameters) atmosphere,
    Length r, Number mu) {
    assert(r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    Area discriminant = r * r * (mu * mu - 1.0) +
        atmosphere.top_radius * atmosphere.top_radius;
    return ClampDistance(-r * mu + SafeSqrt(discriminant));
}

/*
<p>We will also need, in the other sections, the distance to the bottom
atmosphere boundary, which can be computed in a similar way (this code assumes
that $[\bp,\bi)$ intersects the ground):
*/

Length DistanceToBottomAtmosphereBoundary(IN(AtmosphereParameters) atmosphere,
    Length r, Number mu) {
    assert(r >= atmosphere.bottom_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    Area discriminant = r * r * (mu * mu - 1.0) +
        atmosphere.bottom_radius * atmosphere.bottom_radius;
    return ClampDistance(-r * mu - SafeSqrt(discriminant));
}

/*
<h5>Intersections with the ground</h5>

<p>The segment $[\bp,\bi]$ intersects the ground when
$d^2+2r\mu d+r^2=r_{\mathrm{bottom}}^2$ has a solution with $d \ge 0$. This
requires the discriminant $r^2(\mu^2-1)+r_{\mathrm{bottom}}^2$ to be positive,
from which we deduce the following function:
*/

bool RayIntersectsGround(IN(AtmosphereParameters) atmosphere,
    Length r, Number mu) {
    assert(r >= atmosphere.bottom_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    return mu < 0.0 && r * r * (mu * mu - 1.0) +
        atmosphere.bottom_radius * atmosphere.bottom_radius >= 0.0 * m2;
}



/*
<h5>Transmittance to the top atmosphere boundary</h5>

<p>We can now compute the transmittance between $\bp$ and $\bi$. From its
definition and the
<a href="https://en.wikipedia.org/wiki/Beer-Lambert_law">Beer-Lambert law</a>,
this involves the integral of the number density of air molecules along the
segment $[\bp,\bi]$, as well as the integral of the number density of aerosols
and the integral of the number density of air molecules that absorb light
(e.g. ozone) - along the same segment. These 3 integrals have the same form and,
when the segment $[\bp,\bi]$ does not intersect the ground, they can be computed
numerically with the help of the following auxilliary function (using the <a
href="https://en.wikipedia.org/wiki/Trapezoidal_rule">trapezoidal rule</a>):
*/

Number GetLayerDensity(IN(DensityProfileLayer) layer, Length altitude) {
    Number density = layer.exp_term * exp(layer.exp_scale * altitude) +
        layer.linear_term * altitude + layer.constant_term;
    return clamp(density, Number(0.0), Number(1.0));
}

Number GetProfileDensity(IN(DensityProfile) profile, Length altitude) {
    return altitude < profile.layers[0].width ?
        GetLayerDensity(profile.layers[0], altitude) :
        GetLayerDensity(profile.layers[1], altitude);
}

Length ComputeOpticalLengthToTopAtmosphereBoundary(
    IN(AtmosphereParameters) atmosphere, IN(DensityProfile) profile,
    Length r, Number mu) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    // Number of intervals for the numerical integration.
    const int SAMPLE_COUNT = 500;
    // The integration step, i.e. the length of each integration interval.
    Length dx =
        DistanceToTopAtmosphereBoundary(atmosphere, r, mu) / Number(SAMPLE_COUNT);
    // Integration loop.
    Length result = 0.0 * m;
    for (int i = 0; i <= SAMPLE_COUNT; ++i) {
        Length d_i = Number(i) * dx;
        // Distance between the current sample point and the planet center.
        Length r_i = sqrt(d_i * d_i + 2.0 * r * mu * d_i + r * r);
        // Number density at the current sample point (divided by the number density
        // at the bottom of the atmosphere, yielding a dimensionless number).
        Number y_i = GetProfileDensity(profile, r_i - atmosphere.bottom_radius);
        // Sample weight (from the trapezoidal rule).
        Number weight_i = i == 0 || i == SAMPLE_COUNT ? 0.5 : 1.0;
        result += y_i * weight_i * dx;
    }
    return result;
}


/*
<p>With this function the transmittance between $\bp$ and $\bi$ is now easy to
compute (we continue to assume that the segment does not intersect the ground):
*/

DimensionlessSpectrum ComputeTransmittanceToTopAtmosphereBoundary(
    IN(AtmosphereParameters) atmosphere, Length r, Number mu) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    return exp(-(
        atmosphere.rayleigh_scattering *
        ComputeOpticalLengthToTopAtmosphereBoundary(
            atmosphere, atmosphere.rayleigh_density, r, mu) +
        atmosphere.mie_extinction *
        ComputeOpticalLengthToTopAtmosphereBoundary(
            atmosphere, atmosphere.mie_density, r, mu) +
        atmosphere.absorption_extinction *
        ComputeOpticalLengthToTopAtmosphereBoundary(
            atmosphere, atmosphere.absorption_density, r, mu)));
}


/*
<h4 id="transmittance_precomputation">Precomputation</h4>

<p>The above function is quite costly to evaluate, and a lot of evaluations are
needed to compute single and multiple scattering. Fortunately this function
depends on only two parameters and is quite smooth, so we can precompute it in a
small 2D texture to optimize its evaluation.

<p>For this we need a mapping between the function parameters $(r,\mu)$ and the
texture coordinates $(u,v)$, and vice-versa, because these parameters do not
have the same units and range of values. And even if it was the case, storing a
function $f$ from the $[0,1]$ interval in a texture of size $n$ would sample the
function at $0.5/n$, $1.5/n$, ... $(n-0.5)/n$, because texture samples are at
the center of texels. Therefore, this texture would only give us extrapolated
function values at the domain boundaries ($0$ and $1$). To avoid this we need
to store $f(0)$ at the center of texel 0 and $f(1)$ at the center of texel
$n-1$. This can be done with the following mapping from values $x$ in $[0,1]$ to
texture coordinates $u$ in $[0.5/n,1-0.5/n]$ - and its inverse:
*/

Number GetTextureCoordFromUnitRange(Number x, int texture_size) {
    return 0.5 / Number(texture_size) + x * (1.0 - 1.0 / Number(texture_size));
}

Number GetUnitRangeFromTextureCoord(Number u, int texture_size) {
    return (u - 0.5 / Number(texture_size)) / (1.0 - 1.0 / Number(texture_size));
}

/*
<p>Using these functions, we can now define a mapping between $(r,\mu)$ and the
texture coordinates $(u,v)$, and its inverse, which avoid any extrapolation
during texture lookups. In the <a href=
"http://evasion.inrialpes.fr/~Eric.Bruneton/PrecomputedAtmosphericScattering2.zip"
>original implementation</a> this mapping was using some ad-hoc constants chosen
for the Earth atmosphere case. Here we use a generic mapping, working for any
atmosphere, but still providing an increased sampling rate near the horizon.
Our improved mapping is based on the parameterization described in our
<a href="https://hal.inria.fr/inria-00288758/en">paper</a> for the 4D textures:
we use the same mapping for $r$, and a slightly improved mapping for $\mu$
(considering only the case where the view ray does not intersect the ground).
More precisely, we map $\mu$ to a value $x_{\mu}$ between 0 and 1 by considering
the distance $d$ to the top atmosphere boundary, compared to its minimum and
maximum values $d_{\mathrm{min}}=r_{\mathrm{top}}-r$ and
$d_{\mathrm{max}}=\rho+H$ (cf. the notations from the
<a href="https://hal.inria.fr/inria-00288758/en">paper</a> and the figure
below):

<svg width="505px" height="195px">
  <style type="text/css"><![CDATA[
    circle { fill: #000000; stroke: none; }
    path { fill: none; stroke: #000000; }
    text { font-size: 16px; font-style: normal; font-family: Sans; }
    .vector { font-weight: bold; }
  ]]></style>
  <path d="m 5,85 a 520,520 0 0 1 372,105"/>
  <path d="m 5,5 a 600,600 0 0 1 490,185"/>
  <path d="m 60,0 0,190"/>
  <path d="m 60,65 180,-35"/>
  <path d="m 55,5 5,-5 5,5"/>
  <path d="m 55,60 5,5 5,-5"/>
  <path d="m 55,70 5,-5 5,5"/>
  <path d="m 60,40 a 25,25 0 0 1 25,20" style="stroke-dasharray:4,2;"/>
  <path d="m 60,65 415,105"/>
  <circle cx="60" cy="65" r="2.5"/>
  <circle cx="240" cy="30" r="2.5"/>
  <circle cx="180" cy="95" r="2.5"/>
  <circle cx="475" cy="170" r="2.5"/>
  <text x="20" y="40">d<tspan style="font-size:10px" dy="2">min</tspan></text>
  <text x="35" y="70" class="vector">p</text>
  <text x="35" y="125">r</text>
  <text x="75" y="40">mu=cos(theta)</text>
  <text x="120" y="75">phi</text>
  <text x="155" y="60">d</text>
  <text x="315" y="125">H</text>
</svg>

<p>With these definitions, the mapping from $(r,\mu)$ to the texture coordinates
$(u,v)$ can be implemented as follows:
*/


vec2 GetTransmittanceTextureUvFromRMu(IN(AtmosphereParameters) atmosphere,
    Length r, Number mu) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    Length H = sqrt(atmosphere.top_radius * atmosphere.top_radius -
        atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon.
    Length rho =
        SafeSqrt(r * r - atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
    // and maximum values over all mu - obtained for (r,1) and (r,mu_horizon).
    Length d = DistanceToTopAtmosphereBoundary(atmosphere, r, mu);
    Length d_min = atmosphere.top_radius - r;
    Length d_max = rho + H;
    Number x_mu = (d - d_min) / (d_max - d_min);
    Number x_r = rho / H;
    return vec2(GetTextureCoordFromUnitRange(x_mu, TRANSMITTANCE_TEXTURE_WIDTH),
        GetTextureCoordFromUnitRange(x_r, TRANSMITTANCE_TEXTURE_HEIGHT));
}

/*
<p>and the inverse mapping follows immediately:
*/

void GetRMuFromTransmittanceTextureUv(IN(AtmosphereParameters) atmosphere,
    IN(vec2) uv, OUT(Length) r, OUT(Number) mu) {
    assert(uv.x >= 0.0 && uv.x <= 1.0);
    assert(uv.y >= 0.0 && uv.y <= 1.0);
    Number x_mu = GetUnitRangeFromTextureCoord(uv.x, TRANSMITTANCE_TEXTURE_WIDTH);
    Number x_r = GetUnitRangeFromTextureCoord(uv.y, TRANSMITTANCE_TEXTURE_HEIGHT);
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    Length H = sqrt(atmosphere.top_radius * atmosphere.top_radius -
        atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon, from which we can compute r:
    Length rho = H * x_r;
    r = sqrt(rho * rho + atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
    // and maximum values over all mu - obtained for (r,1) and (r,mu_horizon) -
    // from which we can recover mu:
    Length d_min = atmosphere.top_radius - r;
    Length d_max = rho + H;
    Length d = d_min + x_mu * (d_max - d_min);
    mu = d == 0.0 * m ? Number(1.0) : (H * H - rho * rho - d * d) / (2.0 * r * d);
    mu = ClampCosine(mu);
}

/*
<p>It is now easy to define a fragment shader function to precompute a texel of
the transmittance texture:
*/

DimensionlessSpectrum ComputeTransmittanceToTopAtmosphereBoundaryTexture(
    IN(AtmosphereParameters) atmosphere, IN(vec2) frag_coord) {
    const vec2 TRANSMITTANCE_TEXTURE_SIZE =
        vec2(TRANSMITTANCE_TEXTURE_WIDTH, TRANSMITTANCE_TEXTURE_HEIGHT);
    Length r;
    Number mu;
    GetRMuFromTransmittanceTextureUv(
        atmosphere, frag_coord / TRANSMITTANCE_TEXTURE_SIZE, r, mu);
    return ComputeTransmittanceToTopAtmosphereBoundary(atmosphere, r, mu);
}

/*
<h4 id="transmittance_lookup">Lookup</h4>

<p>With the help of the above precomputed texture, we can now get the
transmittance between a point and the top atmosphere boundary with a single
texture lookup (assuming there is no intersection with the ground):
*/

DimensionlessSpectrum GetTransmittanceToTopAtmosphereBoundary(
    IN(AtmosphereParameters) atmosphere,
    IN(TransmittanceTexture) transmittance_texture,
    Length r, Number mu) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    vec2 uv = GetTransmittanceTextureUvFromRMu(atmosphere, r, mu);
    return DimensionlessSpectrum(texture(transmittance_texture, uv).rgb);
}

/*
<p>Also, with $r_d=\Vert\bo\bq\Vert=\sqrt{d^2+2r\mu d+r^2}$ and $\mu_d=
\bo\bq\cdot\bp\bi/\Vert\bo\bq\Vert\Vert\bp\bi\Vert=(r\mu+d)/r_d$ the values of
$r$ and $\mu$ at $\bq$, we can get the transmittance between two arbitrary
points $\bp$ and $\bq$ inside the atmosphere with only two texture lookups
(recall that the transmittance between $\bp$ and $\bq$ is the transmittance
between $\bp$ and the top atmosphere boundary, divided by the transmittance
between $\bq$ and the top atmosphere boundary, or the reverse - we continue to
assume that the segment between the two points does not intersect the ground):
*/

DimensionlessSpectrum GetTransmittance(
    IN(AtmosphereParameters) atmosphere,
    IN(TransmittanceTexture) transmittance_texture,
    Length r, Number mu, Length d, bool ray_r_mu_intersects_ground) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    assert(d >= 0.0 * m);

    Length r_d = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
    Number mu_d = ClampCosine((r * mu + d) / r_d);

    if (ray_r_mu_intersects_ground) {
        return min(
            GetTransmittanceToTopAtmosphereBoundary(
                atmosphere, transmittance_texture, r_d, -mu_d) /
            GetTransmittanceToTopAtmosphereBoundary(
                atmosphere, transmittance_texture, r, -mu),
            DimensionlessSpectrum(1.0, 1.0, 1.0));
    }
    else {
        return min(
            GetTransmittanceToTopAtmosphereBoundary(
                atmosphere, transmittance_texture, r, mu) /
            GetTransmittanceToTopAtmosphereBoundary(
                atmosphere, transmittance_texture, r_d, mu_d),
            DimensionlessSpectrum(1.0, 1.0, 1.0));
    }
}

/*
<p>where <code>ray_r_mu_intersects_ground</code> should be true iif the ray
defined by $r$ and $\mu$ intersects the ground. We don't compute it here with
<code>RayIntersectsGround</code> because the result could be wrong for rays
very close to the horizon, due to the finite precision and rounding errors of
floating point operations. And also because the caller generally has more robust
ways to know whether a ray intersects the ground or not (see below).

<p>Finally, we will also need the transmittance between a point in the
atmosphere and the Sun. The Sun is not a point light source, so this is an
integral of the transmittance over the Sun disc. Here we consider that the
transmittance is constant over this disc, except below the horizon, where the
transmittance is 0. As a consequence, the transmittance to the Sun can be
computed with <code>GetTransmittanceToTopAtmosphereBoundary</code>, times the
fraction of the Sun disc which is above the horizon.

<p>This fraction varies from 0 when the Sun zenith angle $\theta_s$ is larger
than the horizon zenith angle $\theta_h$ plus the Sun angular radius $\alpha_s$,
to 1 when $\theta_s$ is smaller than $\theta_h-\alpha_s$. Equivalently, it
varies from 0 when $\mu_s=\cos\theta_s$ is smaller than
$\cos(\theta_h+\alpha_s)\approx\cos\theta_h-\alpha_s\sin\theta_h$ to 1 when
$\mu_s$ is larger than
$\cos(\theta_h-\alpha_s)\approx\cos\theta_h+\alpha_s\sin\theta_h$. In between,
the visible Sun disc fraction varies approximately like a smoothstep (this can
be verified by plotting the area of <a
href="https://en.wikipedia.org/wiki/Circular_segment">circular segment</a> as a
function of its <a href="https://en.wikipedia.org/wiki/Sagitta_(geometry)"
>sagitta</a>). Therefore, since $\sin\theta_h=r_{\mathrm{bottom}}/r$, we can
approximate the transmittance to the Sun with the following function:
*/

DimensionlessSpectrum GetTransmittanceToSun(
    IN(AtmosphereParameters) atmosphere,
    IN(TransmittanceTexture) transmittance_texture,
    Length r, Number mu_s) {
    Number sin_theta_h = atmosphere.bottom_radius / r;
    Number cos_theta_h = -sqrt(max(1.0 - sin_theta_h * sin_theta_h, 0.0));
    return GetTransmittanceToTopAtmosphereBoundary(
        atmosphere, transmittance_texture, r, mu_s) *
        smoothstep(-sin_theta_h * atmosphere.sun_angular_radius / rad,
            sin_theta_h * atmosphere.sun_angular_radius / rad,
            mu_s - cos_theta_h);
}

