#version 450

layout (location = 0) in vec3 inNormal;
layout (location = 1) in vec3 inColor;

layout (location = 0) out vec4 outFragColor;

layout (set = 0, binding = 0) uniform SceneData{
	vec4 lightDir;
} sceneData;

void main() {
	const float nl = max(0., dot(inNormal, sceneData.lightDir.xyz));
	outFragColor = vec4(nl * inColor, 1.);
}
