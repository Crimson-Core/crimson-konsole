shader_type canvas_item;
//I DONT OWN THIS i just took it directly from balatro source code
//and then converted it into godots shader language
//shoutouts localthunk, buy balatro now: https://www.playbalatro.com
uniform bool polar_coordinates = false;  // cool polar coordinates effect, this is use in card
uniform vec2 polar_center = vec2(0.5);
uniform float polar_zoom = 1.;
uniform float polar_repeat = 1.;
uniform highp float spin_rotation;
uniform highp float spin_speed = 1;
uniform highp vec2 offset = vec2(0., 0.);
uniform highp vec4 colour_1 : source_color;
uniform highp vec4 colour_2 : source_color;
uniform highp vec4 colour_3 : source_color;
uniform highp float contrast = 2.;
uniform highp float lighting = 0.4;
uniform highp float spin_amount = 0.36;
uniform highp float pixel_filter = 700.;
#define SPIN_EASE 1.0
vec4 effect(vec2 screenSize, vec2 screen_coords){
	//Convert to UV coords (0-1) - убрал floor() для убирания пикселизации
    highp vec2 uv = (screen_coords.xy - 0.5*screenSize.xy)/length(screenSize.xy) - offset;
    highp float uv_len = length(uv);
	//Adding in a center swirl, changes with time. Only applies meaningfully if the 'spin amount' is a non-zero number
    highp float speed = (spin_rotation*SPIN_EASE*0.2) + 302.2;
    highp float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
    highp vec2 mid = (screenSize.xy/length(screenSize.xy))/2.;
    uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
	//Now add the paint effect to the swirled UV
    uv *= 30.;
    speed = TIME*(spin_speed);
	highp vec2 uv2 = vec2(uv.x+uv.y);
	for(int i=0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
		uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
	}
	//Make the paint amount range from 0 - 2
    highp float contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
	highp float paint_res = min(2., max(0.,length(uv)*(0.035)*contrast_mod));
    highp float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
    highp float c2p = max(0.,1. - contrast_mod*abs(paint_res));
    highp float c3p = 1. - min(1., c1p + c2p);
	highp float ligth = (lighting - 0.2) * max(c1p*5. - 4., 0.) + lighting * max(c2p*5. - 4., 0.);
	highp vec4 ret_col = (0.3/contrast)*colour_1 + (1. - 0.3/contrast)*(colour_1*c1p + colour_2*c2p + vec4(c3p*colour_3.rgb, c3p*colour_1.a)) + ligth;
	return ret_col;
}
vec2 polar_coords(vec2 uv, vec2 center, float zoom, float repeat){
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y , dir.x) * 1.0 / (PI * 2.0);
	return mod(vec2(radius * zoom, angle * repeat), 1.0);
}
void fragment() {
	vec2 polarCoords = UV;
	if (polar_coordinates){
		polarCoords = polar_coords(UV.xy, polar_center, polar_zoom, polar_repeat);
	}
	COLOR *= effect(TEXTURE_PIXEL_SIZE, polarCoords);
}