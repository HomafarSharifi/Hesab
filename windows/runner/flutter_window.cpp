#include "flutter_window.h"

#include <dwmapi.h>

#include <cstdint>
#include <optional>
#include <variant>

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif
#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif

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
        if (call.method_name() != "setCaptionColors") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("invalid_arguments", "Expected caption color map");
          return;
        }

        const auto background =
            arguments->find(flutter::EncodableValue("background"));
        const auto foreground =
            arguments->find(flutter::EncodableValue("foreground"));
        if (background == arguments->end() || foreground == arguments->end()) {
          result->Error("invalid_arguments", "Caption colors are required");
          return;
        }

        const auto* background_argb =
            std::get_if<int64_t>(&background->second);
        const auto* foreground_argb =
            std::get_if<int64_t>(&foreground->second);
        if (background_argb == nullptr || foreground_argb == nullptr) {
          result->Error("invalid_arguments", "Caption colors must be integers");
          return;
        }

        const auto to_color_ref = [](int64_t argb) {
          const auto color = static_cast<uint32_t>(argb);
          return RGB((color >> 16) & 0xFF, (color >> 8) & 0xFF,
                     color & 0xFF);
        };
        const COLORREF caption_color = to_color_ref(*background_argb);
        const COLORREF caption_text_color = to_color_ref(*foreground_argb);
        DwmSetWindowAttribute(GetHandle(), DWMWA_BORDER_COLOR, &caption_color,
                              sizeof(caption_color));
        DwmSetWindowAttribute(GetHandle(), DWMWA_CAPTION_COLOR, &caption_color,
                              sizeof(caption_color));
        DwmSetWindowAttribute(GetHandle(), DWMWA_TEXT_COLOR,
                              &caption_text_color,
                              sizeof(caption_text_color));
        result->Success();
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
