shader_type canvas_item;

// Variação de uniforme para os inimigos, sem novos sprites.
//
// - Faixas 1 e 2: pixels cujo matiz está dentro da faixa (e com saturação e
//   brilho mínimos) têm o matiz girado e a saturação/brilho ajustados.
//   Ex.: o roxo da camisa do Zagueiro vira vermelho, verde, azul...
// - Escuros: pixels escuros e pouco saturados (uniforme preto do Juiz, calções)
//   ganham uma cor, mantendo o sombreado original.
// - A pele (matiz entre pele_matiz_min e pele_matiz_max, com saturação acima
//   de pele_sat_min) e o contorno preto nunca são alterados.
// - O modulate do nó (piscar ao levar dano) continua funcionando.

uniform bool faixa1_ativa = false;
uniform float faixa1_centro : hint_range(0.0, 360.0) = 0.0;
uniform float faixa1_largura : hint_range(0.0, 180.0) = 20.0;
uniform float faixa1_sat_min : hint_range(0.0, 1.0) = 0.3;
uniform float faixa1_val_min : hint_range(0.0, 1.0) = 0.05;
uniform float faixa1_val_max : hint_range(0.0, 1.0) = 1.0;
uniform float faixa1_giro : hint_range(-360.0, 360.0) = 0.0;
uniform float faixa1_sat : hint_range(0.0, 3.0) = 1.0;
uniform float faixa1_val : hint_range(0.0, 3.0) = 1.0;

uniform bool faixa2_ativa = false;
uniform float faixa2_centro : hint_range(0.0, 360.0) = 0.0;
uniform float faixa2_largura : hint_range(0.0, 180.0) = 20.0;
uniform float faixa2_sat_min : hint_range(0.0, 1.0) = 0.3;
uniform float faixa2_val_min : hint_range(0.0, 1.0) = 0.05;
uniform float faixa2_val_max : hint_range(0.0, 1.0) = 1.0;
uniform float faixa2_giro : hint_range(-360.0, 360.0) = 0.0;
uniform float faixa2_sat : hint_range(0.0, 3.0) = 1.0;
uniform float faixa2_val : hint_range(0.0, 3.0) = 1.0;

uniform bool escuros_ativo = false;
uniform vec4 escuros_cor : source_color = vec4(1.0);
uniform float escuros_val_min : hint_range(0.0, 1.0) = 0.05;
uniform float escuros_val_max : hint_range(0.0, 1.0) = 0.32;
uniform float escuros_sat_max : hint_range(0.0, 1.0) = 0.5;
uniform float escuros_brilho_min : hint_range(0.0, 2.0) = 0.3;
uniform float escuros_brilho_max : hint_range(0.0, 2.0) = 1.0;

uniform float pele_matiz_min : hint_range(0.0, 360.0) = 8.0;
uniform float pele_matiz_max : hint_range(0.0, 360.0) = 42.0;
uniform float pele_sat_min : hint_range(0.0, 1.0) = 0.33;

varying vec4 cor_vertice;

vec3 rgb_para_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_para_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// Distância (em graus) entre dois matizes, considerando a volta de 360.
float distancia_matiz(float a, float b) {
	float d = abs(a - b);
	return min(d, 360.0 - d);
}

float peso_faixa(vec3 hsv, float centro, float largura, float sat_min, float val_min, float val_max) {
	float dist = distancia_matiz(hsv.x * 360.0, centro);
	float dentro = 1.0 - smoothstep(largura, largura + 6.0, dist);
	float sat_ok = smoothstep(sat_min - 0.05, sat_min, hsv.y);
	float val_ok = smoothstep(val_min - 0.03, val_min, hsv.z) * (1.0 - smoothstep(val_max, val_max + 0.04, hsv.z));
	return dentro * sat_ok * val_ok;
}

vec3 aplicar_faixa(vec3 hsv, float giro, float sat, float val) {
	return vec3(fract(hsv.x + giro / 360.0), clamp(hsv.y * sat, 0.0, 1.0), clamp(hsv.z * val, 0.0, 1.0));
}

void vertex() {
	cor_vertice = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 cor = tex.rgb;
	vec3 hsv = rgb_para_hsv(cor);

	float graus = hsv.x * 360.0;
	bool tom_de_pele = graus >= pele_matiz_min && graus <= pele_matiz_max;
	float pele = (tom_de_pele && hsv.y >= pele_sat_min && hsv.z > 0.18) ? 1.0 : 0.0;

	vec3 resultado = cor;

	if (faixa1_ativa) {
		float p1 = peso_faixa(hsv, faixa1_centro, faixa1_largura, faixa1_sat_min, faixa1_val_min, faixa1_val_max);
		resultado = mix(resultado, hsv_para_rgb(aplicar_faixa(hsv, faixa1_giro, faixa1_sat, faixa1_val)), p1);
	}

	if (faixa2_ativa) {
		float p2 = peso_faixa(hsv, faixa2_centro, faixa2_largura, faixa2_sat_min, faixa2_val_min, faixa2_val_max);
		resultado = mix(resultado, hsv_para_rgb(aplicar_faixa(hsv, faixa2_giro, faixa2_sat, faixa2_val)), p2);
	}

	if (escuros_ativo) {
		float faixa_valor = smoothstep(escuros_val_min, escuros_val_min + 0.03, hsv.z) * (1.0 - smoothstep(escuros_val_max - 0.04, escuros_val_max, hsv.z));
		float pouco_saturado = 1.0 - smoothstep(escuros_sat_max - 0.08, escuros_sat_max, hsv.y);
		// Tons de pele escuros e saturados são sombra de pele/cabelo: ficam como estão
		float nao_pele = (tom_de_pele && hsv.y > pele_sat_min) ? 0.0 : 1.0;
		float t = clamp((hsv.z - escuros_val_min) / max(escuros_val_max - escuros_val_min, 0.001), 0.0, 1.0);
		vec3 tingido = escuros_cor.rgb * mix(escuros_brilho_min, escuros_brilho_max, t);
		resultado = mix(resultado, tingido, faixa_valor * pouco_saturado * nao_pele);
	}

	// A pele nunca muda
	resultado = mix(resultado, cor, pele);

	COLOR = vec4(resultado, tex.a) * cor_vertice;
}
