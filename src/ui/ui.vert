#version 450

layout (location = 0) in vec2 inPos;
layout (location = 1) in vec2 inUV;
layout (location = 2) in vec4 inColor;

layout (push_constant) uniform PushConstants {
	vec4 scale_translate;
} pushConstants;

layout (location = 0) out vec2 outUV;
layout (location = 1) out vec4 outColor;

out gl_PerVertex {
	vec4 gl_Position;
};

void main() {
	outUV = inUV;
	outColor = inColor;
	gl_Position = vec4(inPos * pushConstants.scale_translate.xy + pushConstants.scale_translate.zw, 0., 1.);
}

