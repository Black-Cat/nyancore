#version 460

layout (location = 0) in vec3 inPosition;
layout (location = 1) in vec3 inNormal;
//layout (location = 2) in vec3 inColor;

layout (location = 0) out vec3 outNormal;
layout (location = 1) out vec3 outColor;

layout (set = 0, binding = 0) uniform CameraBuffer {
	mat4 viewProj;
} cameraData;

struct ObjectData{
	mat4 transform;
};

layout (std140,set = 1, binding = 0) readonly buffer ObjectBuffer {
	ObjectData objects[];
} objectBuffer;

void main() {
	mat4 transform = objectBuffer.objects[gl_BaseInstance].transform;
	mat4 transformMatrix = cameraData.viewProj * transform;
	gl_Position = transformMatrix * vec4(inPosition, 1.);
	outNormal = inNormal;
	outColor = vec3(.7);
}
