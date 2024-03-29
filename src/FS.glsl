#version 300 es
precision highp float;

uniform float time;
uniform float aspectRatio;

/////////////////////////////////////////////////////////////////////////////////////
//	==================
//		Constants
//	==================
const int MAX_MARCHING_STEPS		= 150;
const float SURFACE_THRESHOLD		= 0.001;
const float MAX_MARCHING_DISTANCE	= 15.0;
const float PI 						= 3.14159265359;
const float AMBIENT					= 0.75;
const vec3	lPos1					= vec3(0.0, 4.0, 2.0);

const mat3 m3 = mat3(		0.00	,  0.80	,  0.60	,
							-0.80	,  0.36	, -0.48	,
							-0.60	, -0.48	,  0.64 );

const mat3 m3i	= mat3(		0.00	, -0.80	, -0.60	,
							0.80	,  0.36	, -0.48	,
							0.60	, -0.48	,  0.64 );

const mat2 m2	= mat2(		0.80	,  0.60	,
                    		-0.60	,  0.80 );

const mat2 m2i	= mat2(		0.80	, -0.60	,
							0.60	,  0.80 );

/////////////////////////////////////////////////////////////////////////////////////
//	==================
//		Structs
//	==================
struct Ray 
{
    vec3 dir;
    vec3 org;
};

/////////////////////////////////////////////////////////////////////////////////////
//	==================
//		Functions
//	==================
mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) 
{
	vec3 f = normalize(center - eye);
	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);

	return mat4(	vec4(s, 0.0),
					vec4(u, 0.0),
					vec4(-f, 0.0),
					vec4(0.0, 0.0, 0.0, 1.0));
}

vec4 blend(float a, float b, vec3 colA, vec3 colB, float k) 
{
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	float blendDst = mix(b, a, h) - k * h * (1.0 - h);
	vec3 blendCol = mix(colB, colA, h);

	return vec4(blendCol, blendDst);
}

mat3 rotateX(float angle) 
{
	float s = sin(angle);
	float c = cos(angle);
	return mat3
	(
		1.0	, 0.0	, 0.0,
		0.0	, c		, -s,
		0.0	, s		,  c
	);
}

mat3 rotateY(float angle) 
{
	float s = sin(angle);
	float c = cos(angle);
	return mat3
	(
		 c	, 0.0	, s,
		0.0	, 1.0	, 0.0,
		-s	, 0.0	, c
	);
}

mat3 rotateZ(float angle) 
{
	float s = sin(angle);
	float c = cos(angle);
	return mat3
	(
		c	, -s	, 0.0,
		s	,  c	, 0.0,
		0.0	, 0.0	, 1.0
	);
}

mat3 rotateXYZ(vec3 angles) 
{
    return rotateX(angles.x) * rotateY(angles.y) * rotateZ(angles.z);
}

mat3 lookAt(vec3 originalDir, vec3 targetDir) 
{
	vec3 v = cross(originalDir, targetDir);
	float c = dot(originalDir, targetDir);
	float k = 1.0 / (1.0 + c);

	mat3 result = mat3(
		v.x * v.x * k + c, v.y * v.x * k - v.z, v.z * v.x * k + v.y,
		v.x * v.y * k + v.z, v.y * v.y * k + c, v.z * v.y * k - v.x,
		v.x * v.z * k - v.y, v.y * v.z * k + v.x, v.z * v.z * k + c
	);

	return result;
}

float squarePattern(float p) 
{
    float segmentSize = 0.5;
    float value = mod(p, segmentSize);
    return value > (segmentSize / 2.0) ? 0.5 : -0.5;
}

float dot2(in vec3 v ) { return dot(v,v); }

/////////////////////////////////////////////////////////////////////////////////////
//	https://iquilezles.org/articles/distfunctions/


float sdMeta(vec3 v, float r, float f) 
{
	vec3 	p 	= v;
	float 	rad = r + 0.1 * sin(p.x * f + time * -2.0) 	* 
							cos(p.y * f + time * 1.0) 	* 	
							cos(p.z * f + time * 2.0);
	return length(p) - rad;
}

float sdSphere(vec3 p, float r) 
{
	return length(p) - r;
}

float sdCylinder(vec3 p, float r, float h) 
{
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0)));
}

float sdSphereRandom(vec3 i, vec3 f, vec3 c) 
{
    vec3 	p	= 17.0 * fract((i + c) * 0.3183099 + vec3(0.11, 0.17, 0.13));
    float 	w 	= fract(p.x * p.y * p.z * (p.x + p.y + p.z));
    float 	r 	= 0.7 * w * w;
    return length(f - c) - r;
}

float sdCappedCylinder( vec3 p, float h, float r )
{
	vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdCappedCone( vec3 p, vec3 a, vec3 b, float ra, float rb )
{
  float rba  	= rb-ra;
  float baba 	= dot(b-a,b-a);
  float papa 	= dot(p-a,p-a);
  float paba 	= dot(p-a,b-a)/baba;
  float x    	= sqrt( papa - paba*paba*baba );
  float cax  	= max(0.0,x-((paba<0.5)?ra:rb));
  float cay  	= abs(paba-0.5)-0.5;
  float k    	= rba*rba + baba;
  float f    	= clamp( (rba*(x-ra)+paba*baba)/k, 0.0, 1.0 );
  float cbx  	= x-ra - f*rba;
  float cby  	= paba - f;
  float s    	= (cbx<0.0 && cay<0.0) ? -1.0 : 1.0;
  return s*sqrt( min(cax*cax + cay*cay*baba,
                     cbx*cbx + cby*cby*baba) );
}

float sdRoundCone( vec3 p, vec3 a, vec3 b, float r1, float r2 )
{
  vec3  ba  	= b - a;
  float l2  	= dot(ba,ba);
  float rr  	= r1 - r2;
  float a2  	= l2 - rr*rr;
  float il2 	= 1.0/l2;
  vec3  pa  	= p - a;
  float y   	= dot(pa,ba);
  float z   	= y - l2;
  float x2  	= dot2( pa*l2 - ba*y );
  float y2  	= y*y*l2;
  float z2  	= z*z*l2;
  float k   	= sign(rr)*rr*rr*x2;
  if( sign(z)*a2*z2>k ) return  sqrt(x2 + z2)        *il2 - r2;
  if( sign(y)*a2*y2<k ) return  sqrt(x2 + y2)        *il2 - r1;
                        return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;
}

float sdRoundConeR(vec3 p, vec3 a, vec3 b, float r1, float r2, float roundRadius)
{
    vec3 ba = b - a;
    float l2 = dot(ba,ba);
    float rr = r1 - r2;
    float a2 = l2 - rr*rr;
    float il2 = 1.0 / l2;
    vec3 pa = p - a;
    float y = dot(pa,ba);
    float z = y - l2;
    float x2 = dot(pa*l2 - ba*y, pa*l2 - ba*y);
    float y2 = y * y * l2;
    float z2 = z * z * l2;
    float k = sign(rr) * rr * rr * x2;
    float dist;

    if (sign(z) * a2 * z2 > k) dist = sqrt(x2 + z2) * il2 - r2;
    else if (sign(y) * a2 * y2 < k) dist = sqrt(x2 + y2) * il2 - r1;
    else dist = (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1;
    dist -= roundRadius;

    return dist;
}


float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
	vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
	return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float sdBox(vec3 p, vec3 b) 
{
    vec3 q = abs(p) - b;
    return length(vec3(max(q.x, 0.0), max(q.y, 0.0), max(q.z, 0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdRoundBox(vec3 p, vec3 b, float r)
{
	vec3 q = abs(p) - b + r;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdSpherifiedBox(vec3 p, vec3 b, float r, float s) 
{
    float boxDist = length(max(abs(p) - b, 0.0)) - r;
    float sphereDist = length(p) - (min(min(b.x, b.y), b.z) + r);
    return mix(boxDist, sphereDist, s);
}

float sdPlane(vec3 p, vec3 n, float h) 
{
    return dot(p, n) + h;
}

float sdOctahedron(vec3 v, float s) 
{
    vec3 p = abs(v);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

float sdBase(vec3 p) 
{
	vec3 i = floor(p);
	vec3 f = fract(p);
	
	return min(min(	min(	sdSphereRandom(i, f, vec3(0.0, 0.0, 0.0)),
							sdSphereRandom(i, f, vec3(0.0, 0.0, 1.0))),
					min(	sdSphereRandom(i, f, vec3(0.0, 1.0, 0.0)),
							sdSphereRandom(i, f, vec3(0.0, 1.0, 1.0)))),
				min(min(	sdSphereRandom(i, f, vec3(1.0, 0.0, 0.0)),
							sdSphereRandom(i, f, vec3(1.0, 0.0, 1.0))),
					min(	sdSphereRandom(i, f, vec3(1.0, 1.0, 0.0)),
							sdSphereRandom(i, f, vec3(1.0, 1.0, 1.0)))));
}

/////////////////////////////////////////////////////////////////////////////////////

float unite(		float a, float b) { return min( a, b); }
float subtract(		float a, float b) { return max(-a, b); }
float intersect(	float a, float b) { return max( a, b); }

float smin(float a, float b, float k) 
{
    float h = max(k - abs(a - b), 0.0);
    return min(a, b) - h * h * 0.25 / k;
}

float smax(float a, float b, float k) 
{
    float h = max(k - abs(a - b), 0.0);
    return max(a, b) + h * h * 0.25 / k;
}

float hash1d(float n) { return fract(n * 17.0 * fract(n * 0.3183099)); }

float hash2d(vec2 p) 
{
    vec2 x = 50.0 * fract(p * 0.3183099);
    return fract(x.x * x.y * (x.x + x.y));
}

vec2 hash2dB(vec2 p) 
{
    vec2 n = vec2(dot(p, vec2(127.1, 311.7)),
                  dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(n) * 43758.5453123);
}

float hash3d(vec3 p) 
{
    vec3 	x = 50.0 * fract(p * vec3(0.3183099, 0.3183099, 0.3183099));
    float 	y = x.x * x.y * x.z * (x.x + x.y + x.z);
    return fract(y);
}

float noise3d(vec3 x) 
{
	vec3	p	= floor(x);
	vec3	w 	= fract(x);
	vec3	u 	= w * w * w * (w * (w * 6.0 - 15.0) + 10.0);
	float	n	= p.x + 317.0 * p.y + 157.0 * p.z;

	float 	a	= hash1d(n + 0.0);
	float 	b	= hash1d(n + 1.0);
	float 	c	= hash1d(n + 317.0);
	float 	d	= hash1d(n + 318.0);
	float 	e	= hash1d(n + 157.0);
	float 	f	= hash1d(n + 158.0);
	float 	g	= hash1d(n + 474.0);
	float 	h	= hash1d(n + 475.0);

	float 	k0	=   a;
	float 	k1	=   b - a;
	float 	k2	=   c - a;
	float 	k3	=   e - a;
	float 	k4	=   a - b - c + d;
	float 	k5	=   a - c - e + g;
	float 	k6	=   a - b - e + f;
	float 	k7	= - a + b + c - d + e - f - g + h;

	return -1.0 + 2.0 * (k0 + k1 * u.x + k2 * u.y + k3 * u.z + k4 * u.x * u.y + k5 * u.y * u.z + k6 * u.z * u.x + k7 * u.x * u.y * u.z);
}

float noise2d(vec2 x) 
{
	vec2 p	= floor(x);
	vec2 w	= fract(x);
	vec2 u	= w * w * w * (w * (w * 6.0 - 15.0) + 10.0);

	float a	= hash2d(p + vec2(0,0));
	float b	= hash2d(p + vec2(1,0));
	float c	= hash2d(p + vec2(0,1));
	float d	= hash2d(p + vec2(1,1));

	return -1.0 + 2.0 * (a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y);
}


//	===================
//		Cos Palette
//	===================
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d)
{
    return a + b * cos(6.28318 * (c * t + d));
}

vec3 paletteSand(float t)
{
	return vec3(0.93855, 0.63795, 0.5573);
}

vec3 paletteRock(float t)
{
	return vec3(0.29, 0.25, 0.2);
}

vec3 paletteSky(float t)
{
	return vec3(0.53, 0.81, 0.98);
}

vec3 paletteHaze(float t)
{
	return vec3(0.77, 0.7, 0.62);
}

//	===================
//		Scenegraph
//	===================
vec4 scene(vec3 v, float distCurrent) 
{
	vec3 	p 			= v;
	float	globalDst 	= MAX_MARCHING_DISTANCE;
	vec3	c 			= vec3(1.0);
	vec3	transform	= vec3(0.0,-0.3,0.0);
	float	d 			= 0.0;

	p = p + transform;

	float	bb 			= clamp(sdBox(p, vec3(4.0)), 0.0001, 8.0);
	if(bb > 8.0) { return vec4(c, bb); }
	//	float unite(		float a, float b) { return min( a, b); }
	//	float subtract(		float a, float b) { return max(-a, b); }
	//	float intersect(	float a, float b) { return max( a, b); }

	//	sdMeta(vec3 v, float r, float f) 
	//	sdSphere(vec3 p, float r) 
	//	sdCylinder(vec3 p, float r, float h) 
	//	sdSphereRandom(vec3 i, vec3 f, vec3 c) 
	//	sdCappedCylinder( vec3 p, float h, float r )
	//	sdCappedCone( vec3 p, vec3 a, vec3 b, float ra, float rb )
	//	sdRoundedCylinder( vec3 p, float ra, float rb, float h )
	//	sdBox(vec3 p, vec3 b) 
	//	sdRoundBox(vec3 p, vec3 b, float r)
	//	sdSpherifiedBox(vec3 p, vec3 b, float r, float s) 
	//	sdPlane(vec3 p, vec3 n, float h) 
	//	sdOctahedron(vec3 v, float s) 
	//	sdBase(vec3 p) 

	vec3 planeColor = vec3(0.98, 0.92, 0.84);
	vec3 faceColor	= vec3(1.40, 0.71, 0.57);
	vec3 suitColor	= vec3(1.40, 0.71, 0.57);
	vec3 shirtColor	= vec3(0.82,0.70,0.68);
	vec3 bodyColor	= vec3(1.4,0.42,0.55);
	vec3 ballColor	= vec3(0.54, 0.14, 0.24) * 1.77;
	vec3 darkColor	= vec3(0.2, 0.1, 0.1);
	vec3 goldColor	= vec3(1.1, 0.75, 0.0);
	vec3 brownColor	= vec3(0.89, 0.56, 0.40);
//	vec3 bellyColor	= vec3(0.2,0.22,0.55);

	vec3 lookDir	= normalize(vec3(0.8, -0.75, -1.1));
	vec3 plugDir	= normalize(lookAt(vec3(0.0, 1.0, 0.0), lookDir) * vec3(0.0, 1.0, 0.0)) * (0.26 + 0.07);
	mat3 beltR		= rotateX(-0.3);
	vec3 headT		= vec3(0.0,0.0,-0.03);	// move the head forward juust a bit

	//	HEAD
	float dPlane	= sdPlane			(p,	 vec3(0.0, 1.0, 0.0), 1.1);
	float dHead 	= sdSpherifiedBox	(p + headT + vec3(0.0, -0.10,  0.00)	,	vec3(0.22, 0.15, 0.18)		, 0.20, 0.7	);
	float dCave 	= sdRoundBox		(p + headT + vec3(0.0, -0.08, -0.40)	,	vec3(0.24, 0.24 - .05, 0.24), 0.14		);
	float dFace 	= sdSpherifiedBox	(p + headT + vec3(0.0, -0.07, -0.19)	,	vec3(0.20, 0.15, 0.01)		, 0.15, 0.5	);
	float dRod		= sdCappedCone		(p + headT + vec3(-0.05, -0.35,  0.01)	,	vec3(0.055,0.20,-0.05) * 0.70	, vec3(0.0), 0.02, 0.075 );
	float dBall		= sdSphere			(p + headT + vec3(-0.05, -0.35,  0.01)	+	vec3(0.055,0.20,-0.05) * -1.20	, 0.14 );
	float dEyeL		= sdRoundBox		(p + headT - vec3(0.0, 0.0, p.y * (p.y - 0.15) * -1.0) + vec3(-0.125, -0.05, -0.30)	,	vec3(0.02, 0.13, 0.05), 0.02);
	float dEyeR		= sdRoundBox		(p + headT - vec3(0.0, 0.0, p.y * (p.y - 0.15) * -1.0) + vec3( 0.125, -0.05, -0.30)	,	vec3(0.02, 0.13, 0.05), 0.02);

	//	BODY
	float dChest	= sdSphere			(p + vec3(-0.02, 0.26, -0.065), 0.04 );
	float dBelly	= sdSphere			(p + vec3(-0.01, 0.45, -0.045), 0.21 );
	float dArmRO	= sdRoundCone		(p + vec3(abs(sin(p.y * -10.0 + 1.0) / 30.0), 0.0, 0.0) ,  vec3( 0.07, 0.270, -0.14) * -1.0, vec3( 0.130, 0.530, -0.30) * -1.0, 0.035, 0.045);
	float dArmLL	= sdRoundCone		(p + vec3(-abs(sin(p.y *  10.0 + 2.5) / 30.0), 0.0, 0.0),  vec3(-0.1, 0.265, -0.14) * -1.0, vec3(-0.1, 0.60, -0.36) * -1.0, 0.035, 0.05);
	float dHandR	= sdSphere			(p + vec3( 0.12, 0.60, -0.32), 0.11 );
	float dHandL	= sdSphere			(p + vec3(-0.080, 0.62, -0.36), 0.11 );

	//	BOMB
	float dBomb		= sdSphere			(p + vec3(-0.01, 0.87, -0.17), 0.26 );
	float dPlug		= sdCappedCone		(p + vec3(-0.01, 0.87, -0.17) + vec3(0.0, -0.023, 0.0), vec3(0.0), plugDir, 0.09, 0.10 );
	float dPlugC	= sdCappedCone		(p + vec3(-0.01, 0.87, -0.17) + vec3(0.0, -0.023, 0.0), vec3(0.0), plugDir, 0.04, 0.06 );
	float dLunt		= sdRoundCone		(p + vec3(-0.01, 0.87, -0.17) + vec3(0.0, -0.023, 0.0), vec3(0.0), plugDir * 1.1, 0.005, 0.03 );

	//	ACCESOIRE
	float dHole		= 				sdRoundBox(p * beltR + vec3(0.0, 0.421, -0.38),	vec3(0.037, 0.020, 0.03), 0.005);
	float dBuckle	= smax(-dHole, 	sdRoundBox(p * beltR + vec3(0.0, 0.421, -0.38),	vec3(0.065, 0.055, 0.01), 0.005), 0.01);
	float dBelt		= max( sdBox(p * rotateX(-0.3) + vec3(0.0, 0.42, -0.045) , vec3(.5, .045, .5)), smin(dChest, dBelly, 0.3) );
	float dLegR		= sdRoundCone		(p,  vec3(-0.01,0.56,0.15) * -1.0, vec3(-0.2,0.6,-0.2) * -1.0, 0.035, 0.05);
	float dLegL		= sdRoundCone		(p,  vec3( 0.02,0.45,0.08) * -1.0, vec3( 0.2,0.7,-0.2) * -1.0, 0.035, 0.05);

	//	SHOES
	vec3 upwR 				= vec3(0.0,-1.0, 0.0);
	vec3 fwdR				= normalize(vec3(1.0, -3.8, -1.5)); 
	vec3 rgtR				= normalize(cross(upwR, fwdR));
	vec3 shoeTR				= vec3(0.3,0.75,-0.3);
	vec3 tipPosR			= fwdR * 0.20;
	vec3 planeNormalR		= normalize(cross(rgtR, fwdR));
	float dShoeBaseR		= sdSphere(p + shoeTR, 0.12);
	float dShoeTipR			= sdSphere(p + shoeTR + tipPosR, 0.08);
	float dShoeR			= 	smax(-sdPlane(p + shoeTR, planeNormalR, dot(vec3(0.0), planeNormalR) + 0.02 - sin(p.y * 11.5 + 0.4) / 70.0),
                   				smin(dShoeBaseR, dShoeTipR, 0.3), 0.02);

	vec3 upwL 				= vec3(0.0,-1.0, 0.0);
	vec3 fwdL				= normalize(vec3(-1.0, -4.4, -1.5)); 
	vec3 rgtL				= normalize(cross(upwL, fwdL));
	vec3 shoeTL				= vec3(-0.3,0.65,-0.3);
	vec3 tipPosL			= fwdL * 0.20;
	vec3 planeNormalL		= normalize(cross(rgtL, fwdL));
	float dShoeBaseL		= sdSphere(p + shoeTL, 0.12);
	float dShoeTipL			= sdSphere(p + shoeTL + tipPosL, 0.08);
	float dShoeL			= 	smax(-sdPlane(p + shoeTL, planeNormalL, dot(vec3(0.0), planeNormalL) + 0.02 ),
                   				smin(dShoeBaseL, dShoeTipL, 0.3), 0.02);
	
	d = dBall;
	d = dHead;
	d = smax( -dCave, d, 0.1);
	d = smin( d, dFace, 0.01);
	d = smin( d, dRod, 0.01);
	d =  min( d, dBall);
	d = smin( d, dEyeL, 0.02);
	d = smin( d, dEyeR, 0.02);
	d =  min( d, smin(dChest, dBelly, 0.2));
	d =  min( d, dArmLL);
	d =  min( d, dArmRO );
	d =  min( d, dHandL);
	d =  min( d, dHandR);
	d =  min( d, smax(-dPlugC, smin(dBomb, dPlug, 0.005), 0.01));
	d =  min( d, dLunt);
	d = smin( d, dBelt, 0.01);
	d =  min( d, dBuckle);
	d =  min( d, dPlane);
	d =  min( d, dShoeR);
	d =  min( d, dShoeL);
	d =  min( d, dLegR);
	d =  min( d, dLegL);


	c = bodyColor;
	c = mix(c, faceColor, step(-0.005, -dFace));
	c = mix(c, ballColor, step(-0.005, -dBall));
	c = mix(c, darkColor, step(-0.005, -dEyeL));
	c = mix(c, darkColor, step(-0.005, -dEyeR));
	c = mix(c, shirtColor, step(-0.001, -dArmLL));
	c = mix(c, shirtColor, step(-0.001, -dArmRO));
	c = mix(c, ballColor, step(-0.001, -dHandL));
	c = mix(c, ballColor, step(-0.001, -dHandR));
	c = mix(c, darkColor, step(-0.001, -smin(dBomb, dPlug, 0.08)));
	c = mix(c, darkColor, step(-0.01, -dBelt));
	c = mix(c, goldColor, step(-0.001, -dBuckle));
	c = mix(c, brownColor, step(-0.001, -dLunt));
	c = mix(c, ballColor, step(-0.001, -dShoeR));
	c = mix(c, ballColor, step(-0.001, -dShoeL));
	c = mix(c, shirtColor, step(-0.001, -dLegR));
	c = mix(c, shirtColor, step(-0.001, -dLegL));
//	c = mix(c, bellyColor, step(-0.001, -smin(dChest, dBelly, 0.2)));
	

	return vec4(c, d);
}

//	===================
//		Raymarching
//	===================

vec3 opRepLim(vec3 p, float s, vec3 lim) 
{
	return p - s * clamp(round(p / s), -lim, lim);
}

vec3 opRep(vec3 p, float s) 
{
	return p - s * round(p / s);
}

vec4 rayMarch(Ray r) 
{
	float distCurrent = 0.0;
	vec4 result;

	for(int i = 0; i < MAX_MARCHING_STEPS; i++) 
	{
		vec3 current 	= r.org + r.dir * distCurrent;
		result			= scene(current, distCurrent);
		if(result.w < SURFACE_THRESHOLD) 		{ return vec4(result.xyz, distCurrent); }
		distCurrent 	+= result.w;
		if(distCurrent > MAX_MARCHING_DISTANCE) { return vec4(-1.0); }
    }

	return vec4(-1.0);
}


float softShadow(vec3 ro, vec3 rd, float mint, float k) 
{
	float res 		= 1.0;
	float t			= mint;
	for(int i = 0; i < 5; i++) 
	{
		vec3 p 		= ro + rd * t;
		float h 	= scene(p, 0.0).w;
		res 		= min(res, 0.5 * k * h / t);
		t 			+= clamp(h, 0.1, 1.0);
		if (h < 0.001) { break; }
	}
	return clamp(res, 0.0, 1.0);
}

float pointLight(vec3 pos, vec3 hit, vec3 normal, float att) 
{
	vec3	lightDir	= normalize(pos - hit);
	float	lightDist 	= length(pos - hit);
	float	attenuation = 1.0 / (1.0 + att * lightDist * lightDist);
	float	intensity	= max(dot(normal, lightDir), 0.0) * attenuation;
	return	intensity;
}

float pointLightSoftShadow(vec3 ro, vec3 lightPos, float k) 
{
	float	res		= 1.0;
	float	t		= 0.01;
	vec3	rd		= normalize(lightPos - ro);
	float	maxDist	= length(lightPos - ro);
    
    for(int i = 0; i < 5; i++) 
	{
		vec3 	p	= ro + rd * t;
		float	h	= scene(p, 0.0).w;
				res	= min(res, k * h / t);
		t += clamp(h, 0.1, 1.0);
        
		if (h < 0.001 || t > maxDist) { break; }
    }
    
	return clamp(res, 0.0, 1.0);
}

vec3 getNormal(vec3 p) 
{
	float 	dist	= scene(p, 0.0).w;
	vec2 	e		= vec2(SURFACE_THRESHOLD, 0.0);
	return normalize(dist - vec3(	scene(p - e.xyy, 0.0).w,
									scene(p - e.yxy, 0.0).w,
									scene(p - e.yyx, 0.0).w));
}

float fresnel(vec3 viewDir, vec3 normal, float reflectivity) 
{
    float cosTheta = dot(-viewDir, normal);
    return reflectivity + (1.0 - reflectivity) * pow(1.0 - cosTheta, 5.0);
}


in vec2 v_uv;
out vec4 FragColor;
void main() 
{
	vec2 uv				= v_uv; uv.x *= aspectRatio;
	vec3 origin			= vec3(0.0);
	vec3 up 			= vec3(0.0, 1.0, 0.0);
	vec3 camPos 		= vec3(0.5 * sin(time / 2.0), 0.1, 2.5 + sin(time / 1.0) / 8.0);
	// mat4 viewMatrix		= viewMatrix(camPos, origin, up);
	// vec3 camDir			= normalize((viewMatrix * vec4(uv, -1.0, 0.0)).xyz);

    float fov			= radians(70.0);
    vec3 forward		= normalize(origin - camPos);
    vec3 right			= normalize(cross(up, forward));
    vec3 newUp			= cross(forward, right);
    vec3 camDir			= normalize(forward - uv.x * right * tan(fov / 2.0) + uv.y * newUp * tan(fov / 2.0));


	Ray ray 			= Ray(camDir, camPos); 
	vec4 result 		= rayMarch(ray);
	float dist 			= result.w;
	vec3 HAZE 			= vec3(1.0); // paletteHaze(0.0);
	vec3 SKY 			= vec3(1.0); // paletteSky(0.0);
	vec3 SUN 			= vec3(4.0, 8.0, 8.0);
	vec3 bgColor		= vec3(0.98, 0.92, 0.84);
	bgColor = vec3(1.0, 0.84, 0.87);


	if(dist == -1.0) 
	{
		// FragColor = vec4(bgColor, 1.0);
	} 
	else 
	{
 		//	vec3 viewDirection = normalize(camPos - hit);
		vec3 color		= result.xyz;
		vec3 hit 		= ray.org + ray.dir * dist;
		vec3 normal 	= getNormal(hit); 
		float fog		= 0.0;
		float fresnel	= min(1.0,max(0.0,fresnel(camDir, normal, 0.2)));

		float shadow 	= clamp(0.0, 1.0, softShadow(hit, normalize(SUN - hit), 0.01, 5.0) + 0.25); 
		float pShadow 	= pow(pointLightSoftShadow(hit, lPos1, 4.0), 0.5); 
		float dPlane	= sdPlane(hit, vec3(0.0, 1.0, 0.0), 1.09);
		float dShade	= sdSphere(hit + vec3(-0.01, 0.97, -0.17), 0.45);
		float dShadeL	= sdSphere(hit + vec3(-0.30, 0.99, -0.30), 0.3);
		float dShadeR	= sdSphere(hit + vec3( 0.30, 0.99, -0.30), 0.3);

		color 			= mix(color, color * 0.8, pow(dot(normal, vec3(0.0, 1.0, 0.0)), 5.0));
		color			= mix(color, vec3(1.0), fresnel);
		color			= mix(color * (clamp(dot(vec3(4.0, 8.0, 6.0), normal) / 15.0, 0.0, 1.0) + AMBIENT), HAZE, fog);
		color			= mix(color, mix(bgColor * 1.25, bgColor, smoothstep(0.0,1.0,length(hit) / 2.0)), step(-0.3, -dPlane));
		color			= mix(color, vec3(0.4, 0.1, 0.1), smoothstep(0.0, 0.55, -dShade));
		color			= mix(color, vec3(0.4, 0.1, 0.1), smoothstep(0.0, 0.45, -dShadeL));
		color			= mix(color, vec3(0.4, 0.1, 0.1), smoothstep(0.0, 0.45, -dShadeR));
	//	color 			=  pow(dot(normal, vec3(0.0, 1.0, 0.0)), 1.0) * pShadow * vec3(1.0, 0.5, 0.0); 
		FragColor 		= vec4(color, 1.0);
	}
}