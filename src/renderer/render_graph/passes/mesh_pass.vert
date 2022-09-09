#version 450

layout (push_constant) uniform PushConstants {
	mat4 transform;
} pushConstants;

layout (location = 0) in vec3 inPosition;
layout (location = 1) in vec3 inNormal;
//layout (location = 2) in vec3 inColor;

layout (location = 0) out vec3 outNormal;
layout (location = 1) out vec3 outColor;

layout (set = 0, binding = 0) uniform CameraBuffer {
	mat4 viewProj;
} cameraData;

void main() {
	mat4 transformMatrix = cameraData.viewProj * pushConstants.transform;
	gl_Position = transformMatrix * vec4(inPosition, 1.);
	outNormal = inNormal;
	outColor = vec3(.7);
}
