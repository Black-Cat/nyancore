#version 450

layout (location = 0) out vec2 outUV;

layout (push_constant) uniform PushConstants {
	vec4 aspect_ratio; // x, y used
} pushConstants;

out gl_PerVertex {
	vec4 gl_Position;
};

void main() {
	float x = -1. + float((gl_VertexIndex & 1) << 2);
	float y = 1. - float((gl_VertexIndex & 2) << 1);

	outUV.x = (x + 1.) * .5;
	outUV.y = (-y + 1.) * .5;

	vec2 ar = pushConstants.aspect_ratio.xy;
	outUV.x = outUV.x * ar.x + (1. - ar.x) / 2.;
	outUV.y = outUV.y * ar.y + (1. - ar.y) / 2.;

	gl_Position = vec4(x, y, 0, 1);
}
