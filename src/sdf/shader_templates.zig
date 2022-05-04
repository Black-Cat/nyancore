pub const layout: []const u8 =
    \\layout(push_constant) uniform PushConstants {
    \\  layout(offset = 16) vec3 eye;
    \\  layout(offset = 32) vec3 up;
    \\  layout(offset = 48) vec3 forward;
    \\} pushConstants;
    \\layout (location = 0) in vec2 inUV;
    \\layout (location = 0) out vec4 outColor;
    \\
;

pub const shader_header: []const u8 =
    \\#define MAP_EPS .001
    \\float dot2(in vec2 v) { return dot(v,v); }
    \\float dot2(in vec3 v) { return dot(v,v); }
    \\float ndot(in vec2 a, in vec2 b) { return a.x * b.x - a.y * b.y; }
    \\float det(in vec2 a, in vec2 b) { return a.x * b.y - b.x * a.y; }
    \\
;

pub const map_header: []const u8 =
    \\float map(in vec3 p) {
    \\  vec3 cpin, cpout;
    \\  vec3 cdin, cdout;
    \\
;

pub const map_footer: []const u8 =
    \\}
    \\
;

pub const mat_to_color_header: []const u8 =
    \\vec3 matToColor(in float m, in vec3 l, in vec3 n, in vec3 v) {
    \\  vec3 res;
    \\
;

pub const mat_to_color_footer: []const u8 =
    \\  res = vec3(1.,0.,1.);
    \\  return res;
    \\}
    \\
;

pub const mat_map_header: []const u8 =
    \\vec3 matMap(in vec3 p, in vec3 l, in vec3 n, in vec3 v) {
    \\  vec3 cpin, cpout;
    \\  float cdin, cdout;
    \\
;

pub const mat_map_footer: []const u8 =
    \\  return matToColor(0.,l,n,v);
    \\}
    \\
;

pub const shader_normal_and_shadows =
    \\vec3 calcNormal(in vec3 pos) {
    \\  const float ep = .0001;
    \\  vec2 e = vec2(1.,-1.)*.5773;
    \\  return normalize(e.xyy * map(pos + e.xyy*ep) +
    \\      e.yyx * map(pos + e.yyx*ep) +
    \\      e.yxy * map(pos + e.yxy*ep) +
    \\      e.xxx * map(pos + e.xxx*ep));
    \\}
    // http://iquilezles.org/www/articles/rmshadows/rmshadows.htm
    \\float calcSoftShadows(in vec3 ro, in vec3 rd, in float mint, in float maxt) {
    \\  float res = 1.;
    \\  float t = mint;
    \\  for (int i = 0; i < ENVIRONMENT_SHADOW_STEPS; i++) {
    \\    float h = map(ro + rd * t);
    \\    float s = clamp(8.*h/t,0.,1.);
    \\    res = min(res, s*s*(3.-2.*s));
    \\    t += clamp(h, .02, .1);
    \\    if (res < .005 || t > maxt) break;
    \\  }
    \\  return clamp(res, 0., 1.);
    \\}
    \\
;

pub const shader_main =
    \\void main() {
    \\  vec2 ip = 2 * inUV - 1.;
    \\
    \\  vec3 tot = vec3(0.);
    \\
    \\#if (CAMERA_PROJECTION == 0)
    \\  float scale = CAMERA_FOV;
    \\#else
    \\  float scale = CAMERA_FOV * length(pushConstants.up);
    \\#endif
    \\
    \\  vec3 right = cross(pushConstants.up, pushConstants.forward);
    \\  vec3 offset = right * ip.x * scale;
    \\  offset += pushConstants.up * ip.y * scale;
    \\
    \\#if (CAMERA_PROJECTION == 0)
    \\  vec3 ro = pushConstants.eye;
    \\  vec3 rd = pushConstants.forward + offset;
    \\  rd = normalize(rd);
    \\#else
    \\  vec3 ro = pushConstants.eye + offset;
    \\  vec3 rd = pushConstants.forward;
    \\#endif
    \\
    \\  float t = CAMERA_NEAR;
    \\  for (int i = 0; i < CAMERA_STEPS; i++) {
    \\    vec3 p = ro + t * rd;
    \\    float h = map(p);
    \\    if (abs(h) < MAP_EPS || t > CAMERA_FAR) break;
    \\    t += h;
    \\  }
    \\
    \\  vec3 col = ENVIRONMENT_BACKGROUND_COLOR;
    \\  if (t < CAMERA_FAR) {
    \\      vec3 pos = ro + t * rd;
    \\      vec3 nor = calcNormal(pos);
    \\      vec3 lig = normalize(ENVIRONMENT_LIGHT_DIR);
    \\      vec3 hal = normalize(lig - rd);
    \\
    \\      col = matMap(pos, lig, nor, rd);
    \\
    \\      float dif = clamp(dot(nor, lig), 0., 1.);
    \\      dif *= calcSoftShadows(pos, lig, .02, 2.5);
    \\
    \\      col *= dif;
    \\  }
    \\#ifdef DISCARD_ENVIRONMENT
    \\  else discard;
    \\#endif
    \\  tot += col;
    \\
    \\  outColor = vec4(tot, 1.);
    \\}
    \\
;
