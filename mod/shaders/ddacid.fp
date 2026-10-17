// Acid mode: Descent moves every vertex by sin(t + its position); here
// the view wobbles the same way.
void main()
{
	vec2 uv = TexCoord;
	float t = timer * 2.0;
	uv.x += sin(t + uv.y * 9.0) * 0.012;
	uv.y += sin(t * 1.5 + uv.x * 7.0) * 0.012;
	FragColor = texture(InputTexture, clamp(uv, 0.0, 1.0));
}
