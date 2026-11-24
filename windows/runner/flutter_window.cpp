#include "flutter_window.h"

#include <map>
#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  window_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "hesab/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "minimize") {
          Minimize();
          result->Success();
          return;
        }
        if (call.method_name() == "toggleMaximize") {
          result->Success(flutter::EncodableValue(ToggleMaximize()));
          return;
        }
        if (call.method_name() == "isMaximized") {
          result->Success(flutter::EncodableValue(IsWindowMaximized()));
          return;
        }
        if (call.method_name() == "close") {
          result->Success();
          Close();
          return;
        }
        if (call.method_name() == "startDragging") {
          StartDragging();
          result->Success();
          return;
        }
        if (call.method_name() == "startResizing") {
          const auto* edge = std::get_if<std::string>(call.arguments());
          if (edge == nullptr) {
            result->Error("invalid_arguments", "Expected a resize edge");
            return;
          }
          const std::map<std::string, WPARAM> resize_edges = {
              {"top", HTTOP}, {"bottom", HTBOTTOM},
              {"left", HTLEFT}, {"right", HTRIGHT},
              {"topLeft", HTTOPLEFT}, {"topRight", HTTOPRIGHT},
              {"bottomLeft", HTBOTTOMLEFT}, {"bottomRight", HTBOTTOMRIGHT}};
          const auto hit = resize_edges.find(*edge);
          if (hit == resize_edges.end()) {
            result->Error("invalid_arguments", "Unknown resize edge");
            return;
          }
          StartResizing(hit->second);
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (window_channel_) {
    window_channel_->SetMethodCallHandler(nullptr);
    window_channel_.reset();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Frameless move/resize and maximize-button clicks use the native
  // non-client path so Windows can handle the window action and Snap Layouts.
  if (message == WM_NCLBUTTONDOWN && wparam != HTMAXBUTTON) {
    return DefWindowProc(hwnd, message, wparam, lparam);
  }

  if (message == WM_NCLBUTTONDOWN || message == WM_NCLBUTTONUP ||
      (message == WM_NCMOUSEMOVE && wparam == HTMAXBUTTON) ||
      message == WM_NCMOUSELEAVE ||
      (message == WM_LBUTTONUP && IsMaximizeButtonPressed()) ||
      message == WM_CAPTURECHANGED ||
      (message == WM_CANCELMODE && IsMaximizeButtonPressed())) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  // Native non-client hit testing must take precedence so Flutter never turns
  // resize borders into client input. All other messages remain Flutter-first.
  if (message == WM_NCCALCSIZE || message == WM_NCHITTEST ||
      message == WM_GETMINMAXINFO) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  if (message == WM_SIZE && window_channel_ &&
      (wparam == SIZE_MAXIMIZED || wparam == SIZE_RESTORED ||
       wparam == SIZE_MINIMIZED)) {
    const bool maximized = IsWindowMaximized();
    if (!last_reported_maximized_.has_value() ||
        *last_reported_maximized_ != maximized) {
      last_reported_maximized_ = maximized;
      window_channel_->InvokeMethod(
          "windowStateChanged",
          std::make_unique<flutter::EncodableValue>(maximized));
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
