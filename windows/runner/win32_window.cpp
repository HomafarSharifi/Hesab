#include "win32_window.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <algorithm>

#include "resource.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// Minimum outer-window dimensions in logical pixels. Keep these aligned with
// ResponsiveDimensions in lib/core/layout/responsive_dimensions.dart.
constexpr int kMinimumWindowWidth = 900;
constexpr int kMinimumWindowHeight = 540;
constexpr int kLinkedResizeStep = 8;

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  // WS_POPUP prevents DWM from recreating a caption on this runner. Retain the
  // thick frame and system window buttons so resizing and maximize semantics
  // continue to work; WM_NCCALCSIZE makes the Flutter client area edge-to-edge.
  constexpr DWORD kFramelessWindowStyle =
      WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU;
  HWND window = CreateWindow(
      window_class, title.c_str(), kFramelessWindowStyle,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);
  const DWM_WINDOW_CORNER_PREFERENCE corner_preference = DWMWCP_ROUND;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT CALLBACK Win32Window::ChildContentSubclassProc(
    HWND const window, UINT const message, WPARAM const wparam,
    LPARAM const lparam, UINT_PTR const subclass_id,
    DWORD_PTR const reference_data) noexcept {
  auto* that = reinterpret_cast<Win32Window*>(reference_data);
  if (that == nullptr) {
    return DefSubclassProc(window, message, wparam, lparam);
  }
  return that->HandleChildContentMessage(window, message, wparam, lparam);
}

LRESULT Win32Window::HandleChildContentMessage(HWND const window,
                                               UINT const message,
                                               WPARAM const wparam,
                                               LPARAM const lparam) noexcept {
  switch (message) {
    case WM_NCHITTEST:
      if (IsMaximizeButtonHit(window, lparam)) return HTMAXBUTTON;
      break;

    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON) {
        TRACKMOUSEEVENT tracking{sizeof(TRACKMOUSEEVENT),
                                TME_LEAVE | TME_NONCLIENT, window, 0};
        TrackMouseEvent(&tracking);
        ForwardNonClientMouseMove(window, lparam, 0);
        return 0;
      }
      break;

    case WM_NCMOUSELEAVE: {
      POINT point{};
      if (GetCursorPos(&point)) {
        MapWindowPoints(nullptr, window, &point, 1);
        DefSubclassProc(window, WM_MOUSEMOVE, 0,
                        MAKELPARAM(point.x, point.y));
      }
      return 0;
    }

    case WM_NCLBUTTONDOWN:
      if (wparam == HTMAXBUTTON) {
        const HWND root = GetAncestor(window, GA_ROOT);
        if (root != nullptr) {
          return SendMessage(root, message, wparam, lparam);
        }
      }
      break;

    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON) {
        const HWND root = GetAncestor(window, GA_ROOT);
        if (root != nullptr) {
          return SendMessage(root, message, wparam, lparam);
        }
      }
      break;
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

bool Win32Window::IsMaximizeButtonHit(HWND const window,
                                      LPARAM const lparam) const {
  POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  MapWindowPoints(nullptr, window, &point, 1);

  RECT client{};
  if (!GetClientRect(window, &client)) return false;

  // Keep these dimensions aligned with the 34 logical-pixel Flutter controls.
  const int button_size = MulDiv(34, GetDpiForWindow(window), 96);
  const RECT maximize_button = {client.right - button_size * 2, 0,
                                client.right - button_size, button_size};
  return PtInRect(&maximize_button, point) != FALSE;
}

bool Win32Window::IsWindowControlsHit(HWND const window,
                                      LPARAM const lparam) const {
  POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  MapWindowPoints(nullptr, window, &point, 1);

  RECT client{};
  if (!GetClientRect(window, &client)) return false;

  const int button_size = MulDiv(34, GetDpiForWindow(window), 96);
  const RECT controls = {client.right - button_size * 3, client.top,
                         client.right, client.top + button_size};
  return PtInRect(&controls, point) != FALSE;
}

void Win32Window::CompleteMaximizeButtonClick(HWND const window,
                                             POINT screen_point) {
  const bool released_on_button = IsMaximizeButtonHit(
      window, MAKELPARAM(screen_point.x, screen_point.y));
  maximize_button_pressed_ = false;
  if (GetCapture() == window) ReleaseCapture();
  if (released_on_button) ToggleMaximize();
}

bool Win32Window::IsMaximizeButtonPressed() const {
  return maximize_button_pressed_;
}

void Win32Window::ForwardNonClientMouseMove(HWND const window,
                                            LPARAM const lparam,
                                            WPARAM const button_state) {
  POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  MapWindowPoints(nullptr, window, &point, 1);
  DefSubclassProc(window, WM_MOUSEMOVE, button_state,
                  MAKELPARAM(point.x, point.y));
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_SIZING: {
      const bool horizontal_resize =
          wparam == WMSZ_LEFT || wparam == WMSZ_RIGHT;
      const bool vertical_resize =
          wparam == WMSZ_TOP || wparam == WMSZ_BOTTOM;
      if (!horizontal_resize && !vertical_resize) break;

      auto bounds = reinterpret_cast<RECT*>(lparam);
      if (bounds == nullptr) break;

      RECT current_bounds{};
      if (!GetWindowRect(hwnd, &current_bounds)) break;

      const int current_height =
          current_bounds.bottom - current_bounds.top;
      const int current_width =
          current_bounds.right - current_bounds.left;
      const UINT dpi = GetDpiForWindow(hwnd);
      if (horizontal_resize) {
        const int proposed_width = bounds->right - bounds->left;
        int height = current_height +
                     MulDiv(proposed_width - current_width, 1,
                            kLinkedResizeStep);
        const int minimum_height = Scale(kMinimumWindowHeight, dpi / 96.0);
        height = (std::max)(height, minimum_height);

        const LONG vertical_center =
            current_bounds.top + current_height / 2;
        bounds->top = vertical_center - height / 2;
        bounds->bottom = bounds->top + height;
      } else {
        const int proposed_height = bounds->bottom - bounds->top;
        int width = current_width +
                    MulDiv(proposed_height - current_height, current_width,
                           current_height);
        const int minimum_width = Scale(kMinimumWindowWidth, dpi / 96.0);
        width = (std::max)(width, minimum_width);

        const LONG horizontal_center =
            current_bounds.left + current_width / 2;
        bounds->left = horizontal_center - width / 2;
        bounds->right = bounds->left + width;
      }
      return TRUE;
    }

    case WM_NCLBUTTONDOWN:
      if (wparam == HTMAXBUTTON) {
        maximize_button_pressed_ = true;
        SetCapture(hwnd);
        if (GetCapture() == hwnd) return 0;
        maximize_button_pressed_ = false;
      }
      break;

    case WM_NCLBUTTONUP:
      if (maximize_button_pressed_) {
        POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        CompleteMaximizeButtonClick(hwnd, point);
        return 0;
      }
      break;

    case WM_LBUTTONUP:
      if (maximize_button_pressed_) {
        POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        ClientToScreen(hwnd, &point);
        CompleteMaximizeButtonClick(hwnd, point);
        return 0;
      }
      break;

    case WM_CAPTURECHANGED:
    case WM_CANCELMODE:
      maximize_button_pressed_ = false;
      break;

    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON && child_content_ != nullptr) {
        TRACKMOUSEEVENT tracking{sizeof(TRACKMOUSEEVENT),
                                TME_LEAVE | TME_NONCLIENT, hwnd, 0};
        TrackMouseEvent(&tracking);
        POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        MapWindowPoints(nullptr, child_content_, &point, 1);
        SendMessage(child_content_, WM_MOUSEMOVE, 0,
                    MAKELPARAM(point.x, point.y));
        return 0;
      }
      break;

    case WM_NCMOUSELEAVE: {
      POINT point{};
      if (child_content_ != nullptr && GetCursorPos(&point)) {
        MapWindowPoints(nullptr, child_content_, &point, 1);
        SendMessage(child_content_, WM_MOUSEMOVE, 0,
                    MAKELPARAM(point.x, point.y));
        return 0;
      }
      break;
    }

    case WM_NCCALCSIZE:
      // Remove the non-client title bar and border while retaining the
      // thick-frame style for native resize gestures and snap layouts.
      if (wparam != 0) {
        return 0;
      }
      break;

    case WM_NCHITTEST: {
      if (IsMaximizeButtonHit(hwnd, lparam)) return HTMAXBUTTON;
      if (IsWindowControlsHit(hwnd, lparam)) return HTCLIENT;
      // Compute resize zones directly from the physical window bounds. The
      // default hit test can report client hits for a popup-style frameless
      // window even where the thick-frame resize cursor is expected.
      if (IsZoomed(hwnd)) return HTCLIENT;
      POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      RECT bounds{};
      if (!GetWindowRect(hwnd, &bounds)) return HTCLIENT;
      const int edge = (std::max)(1, MulDiv(7, GetDpiForWindow(hwnd), 96));
      const bool left = point.x < bounds.left + edge;
      const bool right = point.x >= bounds.right - edge;
      const bool top = point.y < bounds.top + edge;
      const bool bottom = point.y >= bounds.bottom - edge;
      if (top && left) return HTTOPLEFT;
      if (top && right) return HTTOPRIGHT;
      if (bottom && left) return HTBOTTOMLEFT;
      if (bottom && right) return HTBOTTOMRIGHT;
      if (left) return HTLEFT;
      if (right) return HTRIGHT;
      if (top) return HTTOP;
      if (bottom) return HTBOTTOM;
      return HTCLIENT;
    }

    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = GetDpiForWindow(hwnd);
      const double scale_factor = dpi / 96.0;
      info->ptMinTrackSize.x = Scale(kMinimumWindowWidth, scale_factor);
      info->ptMinTrackSize.y = Scale(kMinimumWindowHeight, scale_factor);
      MONITORINFO monitor_info{sizeof(MONITORINFO)};
      if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                         &monitor_info)) {
        info->ptMaxPosition.x = monitor_info.rcWork.left -
                                monitor_info.rcMonitor.left;
        info->ptMaxPosition.y = monitor_info.rcWork.top -
                                monitor_info.rcMonitor.top;
        info->ptMaxSize.x = monitor_info.rcWork.right -
                            monitor_info.rcWork.left;
        info->ptMaxSize.y = monitor_info.rcWork.bottom -
                            monitor_info.rcWork.top;
      }
      return 0;
    }
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  if (child_content_ != nullptr) {
    RemoveWindowSubclass(child_content_, ChildContentSubclassProc,
                         reinterpret_cast<UINT_PTR>(this));
    child_content_ = nullptr;
  }

  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  SetWindowSubclass(content, ChildContentSubclassProc,
                    reinterpret_cast<UINT_PTR>(this),
                    reinterpret_cast<DWORD_PTR>(this));
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

bool Win32Window::IsWindowMaximized() const {
  return window_handle_ != nullptr && IsZoomed(window_handle_);
}

void Win32Window::Minimize() {
  if (window_handle_ != nullptr) ShowWindow(window_handle_, SW_MINIMIZE);
}

bool Win32Window::ToggleMaximize() {
  if (window_handle_ == nullptr) return false;
  ShowWindow(window_handle_, IsZoomed(window_handle_) ? SW_RESTORE : SW_MAXIMIZE);
  return IsZoomed(window_handle_);
}

void Win32Window::Close() {
  if (window_handle_ != nullptr) PostMessage(window_handle_, WM_CLOSE, 0, 0);
}

void Win32Window::StartDragging() {
  if (window_handle_ == nullptr) return;
  POINT cursor{};
  if (!GetCursorPos(&cursor)) return;
  ReleaseCapture();
  SendMessage(window_handle_, WM_NCLBUTTONDOWN, HTCAPTION,
              MAKELPARAM(cursor.x, cursor.y));
}

void Win32Window::StartResizing(WPARAM hit) {
  if (window_handle_ == nullptr || IsZoomed(window_handle_)) return;
  POINT cursor{};
  if (!GetCursorPos(&cursor)) return;
  ReleaseCapture();
  SendMessage(window_handle_, WM_NCLBUTTONDOWN, hit,
              MAKELPARAM(cursor.x, cursor.y));
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
