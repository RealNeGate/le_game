#define _NO_CRT_STDIO_INLINE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <GL/GL.h>

static bool running = true;
static uint64_t frametime = 0;
static uint64_t last_time = 0;

static LRESULT main_wnd_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    if (message == WM_CLOSE) {
        running = false;
        return 0;
    }

    return DefWindowProcA(hwnd, message, wparam, lparam);
}

HWND create(const char* title, int width, int height) {
    HINSTANCE instance = GetModuleHandle(NULL);

    WNDCLASSA wc = { 0 };
    wc.style = (CS_HREDRAW | CS_VREDRAW | CS_OWNDC);
    wc.lpfnWndProc = main_wnd_proc;
    wc.hInstance = GetModuleHandle(NULL);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.lpszClassName = "GAME";
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    if (!RegisterClassA(&wc)) {
        printf("RegisterClassA failed!");
        return NULL;
    }

    const DWORD style = WS_OVERLAPPEDWINDOW;
    const DWORD ex_style = WS_EX_APPWINDOW;

    // Get the size of the border.
    RECT border_rect = { 0 };
    AdjustWindowRectEx(&border_rect, style, false, ex_style);

    RECT monitor_rect;
    GetClientRect(GetDesktopWindow(), &monitor_rect);

    int window_x = (monitor_rect.right / 2) - (width / 2);
    int window_y = (monitor_rect.bottom / 2) - (height / 2);
    int window_w = width;
    int window_h = height;

    // Border rectangle in this case is negative.
    window_x += border_rect.left;
    window_y += border_rect.top;

    // Grow the window size by the OS border. This makes the client width/height correct.
    window_w += border_rect.right - border_rect.left;
    window_h += border_rect.bottom - border_rect.top;

    HWND window_handle = CreateWindowExA(
        WS_EX_APPWINDOW, wc.lpszClassName, title,
        WS_OVERLAPPEDWINDOW,
        window_x, window_y, window_w, window_h,
        0, 0, instance, NULL
    );

    if (window_handle == NULL) {
        printf("Could not create window");
        return NULL;
    }

    // Display the window
    ShowWindow(window_handle, SW_SHOWDEFAULT);
    SetFocus(window_handle);

    load_gl(window_handle);

    // get timer frequency
    LARGE_INTEGER timer_frequency, now;
    QueryPerformanceFrequency(&timer_frequency);
    QueryPerformanceCounter(&now);

    last_time = now.QuadPart;
    frametime = timer_frequency.QuadPart / 60;

    return window_handle;
}

void load_gl(HWND window_handle) {
    // WGL shit
    HDC dc = GetDC(window_handle);
    PIXELFORMATDESCRIPTOR pfd = {
        .nSize = sizeof(pfd),
        .nVersion = 1,
        .iPixelType = PFD_TYPE_RGBA,
        .dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        .cColorBits = 32,
        .cAlphaBits = 8,
        .iLayerType = PFD_MAIN_PLANE
    };

    int pixel_format = ChoosePixelFormat(dc, &pfd);
    SetPixelFormat(dc, pixel_format, &pfd);

    HGLRC glctx = wglCreateContext(dc);
    wglMakeCurrent(dc, glctx);
}

bool update(void) {
    static uint64_t counter = 0;

    MSG message;
    while (PeekMessage(&message, 0, 0, 0, PM_REMOVE)) {
        TranslateMessage(&message);
        DispatchMessage(&message);
    }

    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);
    counter += now.QuadPart - last_time;
    last_time = now.QuadPart;

    // Basic frame limiter
    if (counter >= frametime) {
        counter -= frametime;
        return true;
    } else {
        return false;
    }
}

bool is_running(void) {
    return running;
}

bool key_down(int key) {
    return GetAsyncKeyState(key) & 0x8000;
}

void swap_buffers(HWND window_handle) {
    SwapBuffers(GetDC(window_handle));
}
