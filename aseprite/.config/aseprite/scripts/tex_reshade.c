// Test/Demo file helping development of tex_reshade.lua
// Compile and run with ./cbuild.sh

#include <stdio.h>
#include <memory.h>
#include <string.h>
#include <math.h>

typedef struct { float r, g, b; } Color;
typedef struct { int r, g, b; } Colori;
typedef struct { float h, s, v; } Hsv;

typedef struct {
    float dh; // hue rotation (degrees)
    float ss; // saturation scale
    float vs; // value scale;
} Shift;

char *log_color(Color *c)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "(%.4f %.4f %.4f)", c->r, c->g, c->b);
    return strdup(buffer);
}

char *log_colori(Colori *c)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "(%d %d %d)", c->r, c->g, c->b);
    return strdup(buffer);
}

char *log_hsv(Hsv *c)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "(%.4f, %.4f %.4f)", c->h, c->s, c->v);
    return strdup(buffer);
}

char *log_shift(Shift *sh)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "(%.4f, %.0f, %.0f)", sh->dh, sh->ss, sh->vs);
    return strdup(buffer);
}

int clampc(int c)
{
    return c < 0 ? 0 : c > 255 ? 255 : c;
}

float clampf(float c)
{
    return c < 0.0f ? 0.0f : c > 1.0f ? 1.0f : c;
}

Color colori_to_color(Colori *c)
{
    Color r = { clampc(c->r) / 255.0f, clampc(c->g) / 255.0f, clampc(c->b) / 255.0f };
    return r;
}

Colori color_to_colori(Color *c)
{
    Colori r = { clampc((int)(c->r * 255.0f)), clampc((int)(c->g * 255.0f)), clampc((int)(c->b * 255.0f)) };
    return r;
}

Hsv rgb_to_hsv(Color *c)
{
    float maxColor = fmaxf(c->r, fmaxf(c->g, c->b));
    float minColor = fminf(c->r, fminf(c->g, c->b));
    float delta = maxColor - minColor;

    Hsv r;
    r.v = maxColor;
    r.s = (maxColor <= 0.0f) ? 0.0f : delta / maxColor;

    if (delta <= 0.0f)
    {
        r.h = 0.0f;
        return r;
    }

    float hue;
    if (maxColor == c->r) hue = fmodf((c->g - c->b) / delta, 6.0f);
    else if (maxColor == c->g) hue = (c->b - c->r) / delta + 2.0f;
    else hue = (c->r - c->g) / delta + 4.0f;
    hue *= 60.0f;
    if (hue < 0.0f) hue += 360.0f;
    r.h = hue;
    return r;
}

Color hsv_to_rgb(Hsv *c)
{
    float hue = fmodf(c->h, 360.0f);
    if (hue < 0.0f) hue += 360.0f;
    float saturation = clampf(c->s);
    float vibrance = clampf(c->v);

    float cc = vibrance * saturation;
    float x = cc * (1.0f - fabsf(fmodf(hue / 60.0f, 2.0f) - 1.0f));
    float m = vibrance - cc;

    Color r;
    if (hue < 60.0f) { r.r = cc; r.g = x; r.b = 0; }
    else if (hue < 120.0f) { r.r = x; r.g = cc; r.b = 0; }
    else if (hue < 180.0f) { r.r = 0; r.g = cc; r.b = x; }
    else if (hue < 240.0f) { r.r = 0; r.g = x; r.b = cc; }
    else if (hue < 300.0f) { r.r = x; r.g = 0; r.b = cc; }
    else { r.r = cc; r.g = 0; r.b = x; }

    r.r += m; r.g += m; r.b += m;

    return r;
}

Shift create_shift(Colori *src, Colori *dst)
{
    printf("Create shift\n");
    printf("SRC: %s | DST: %s\n", log_colori(src), log_colori(dst));
    Color csrc = colori_to_color(src);
    Color cdst = colori_to_color(dst);

    printf("fSRC: %s | fDST: %s\n", log_color(&csrc), log_color(&cdst));

    Hsv hsrc = rgb_to_hsv(&csrc);
    Hsv hdst = rgb_to_hsv(&cdst);

    printf("hSRC: %s | hDST: %s\n", log_hsv(&hsrc), log_hsv(&hdst));

    Shift r;
    r.dh = hdst.h - hsrc.h;
    r.ss = (hsrc.s <= 1e-6f) ? 1.0f : (hdst.s / hsrc.s);
    r.vs = (hsrc.v <= 1e-6f) ? 1.0f : (hdst.v / hsrc.v);

    printf("Shift: %s\n", log_shift(&r));
    
    return r;
}

Colori apply_shift(Shift *sh, Colori *vi)
{
    printf("Apply shift\n");
    printf("Shift: %s | Value: %s\n", log_shift(sh), log_colori(vi));

    Color v = colori_to_color(vi);
    printf("fValue: %s\n", log_color(&v));

    Hsv hv = rgb_to_hsv(&v);
    printf("hValue: %s\n", log_hsv(&hv));

    hv.h = fmodf(hv.h + sh->dh + 360.0f, 360.0f);
    hv.s = clampf(hv.s * sh->ss);
    hv.v = clampf(hv.v * sh->vs);

    printf("hResult: %s\n", log_hsv(&hv));

    Color r = hsv_to_rgb(&hv);
    printf("fResult: %s\n", log_color(&r));

    Colori ri = color_to_colori(&r);
    printf("Result: %s\n", log_colori(&ri));

    return ri;
}

typedef struct {
    Colori Source, Dest, Value;
} Test;

void run_test(Test *test)
{
    printf("Source: %s\n", log_colori(&test->Source));
    printf("Dest: %s\n", log_colori(&test->Dest));
    printf("Value: %s\n", log_colori(&test->Value));

    Shift shift = create_shift(&test->Source, &test->Dest);
    Colori result = apply_shift(&shift, &test->Value);

    printf("Test result: %s\n", log_colori(&result));
}

int main(void)
{
    Test tests[] = {
        {
            .Source = { .r = 0, .g = 255, .b = 0 },
            .Dest = { .r = 255, .g = 0, .b = 0 },
            .Value = { .r = 0, .g = 255, .b = 0 }
        },
        {
            .Source = { .r = 128, .g = 255, .b = 200 },
            .Dest = { .r = 255, .g = 0, .b = 0 },
            .Value = { .r = 0, .g = 255, .b = 0 }
        },
        {
            .Source = { .r = 128, .g = 255, .b = 200 },
            .Dest = { .r = 255, .g = 0, .b = 0 },
            .Value = { .r = 255, .g = 0, .b = 0 }
        },
        {
            .Source = { .r = 128, .g = 255, .b = 200 },
            .Dest = { .r = 255, .g = 0, .b = 0 },
            .Value = { .r = 0, .g = 0, .b = 255 }
        },
        {
            .Source = { .r = 0, .g = 255, .b = 0 },
            .Dest = { .r = 128, .g = 255, .b = 200 },
            .Value = { .r = 255, .g = 0, .b = 0 }
        },
        {
            .Source = { .r = 0, .g = 255, .b = 0 },
            .Dest = { .r = 128, .g = 255, .b = 200 },
            .Value = { .r = 0, .g = 255, .b = 0 }
        },
        {
            .Source = { .r = 0, .g = 255, .b = 0 },
            .Dest = { .r = 128, .g = 255, .b = 200 },
            .Value = { .r = 0, .g = 0, .b = 255 }
        },
        {
            .Source = { .r = 0, .g = 255, .b = 0 },
            .Dest = { .r = 128, .g = 255, .b = 200 },
            .Value = { .r = 255, .g = 255, .b = 255 }
        },
        {
            .Source = { .r = 0, .g = 255, .b = 0 },
            .Dest = { .r = 128, .g = 255, .b = 200 },
            .Value = { .r = 0, .g = 0, .b = 0 }
        },
    };

    int len = sizeof(tests) / sizeof(Test);
    for (int i = 0; i < len; ++i)
    {
        printf("TEST %d START\n", i);

        run_test(&tests[i]);

        printf("TEST %d END\n", i);
    }

    return 0;
}