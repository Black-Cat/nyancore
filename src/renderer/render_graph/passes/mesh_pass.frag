#version 450

layout (location = 0) in vec3 inNormal;
layout (location = 1) in vec3 inColor;

layout (location = 0) out vec4 outFragColor;

void main() {
	const vec3 light = vec3(1.);
	const float nl = max(0., dot(inNormal, light));
	outFragColor = vec4(nl * inColor, 1.);
}
