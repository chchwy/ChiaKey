#pragma once

#include <Windows.h>

#include <string>
#include <functional>
#include <vector>

#include "ChiaKeyEngine.h"

namespace ChiaKey::WindowsTsf {

struct CandidatePalette {
    COLORREF background = RGB(0, 0, 0);
    COLORREF pattern = RGB(32, 32, 32);
    COLORREF foreground = RGB(255, 255, 255);
    COLORREF highlight = RGB(140, 91, 156);
    COLORREF highlightEnd = RGB(140, 91, 156);
    bool usePattern = false;
};

// after Yahoo! KeyKey's BICandidateForm (Loaders/Windows-IMM/BaseIMEUI)
class CandidateWindow final {
public:
    CandidateWindow() = default;
    ~CandidateWindow();

    CandidateWindow(const CandidateWindow&) = delete;
    CandidateWindow& operator=(const CandidateWindow&) = delete;

    void show(HWND owner, const RECT& textRect, const EngineResult& result);
    void showMessage(HWND owner, const RECT& textRect, const std::wstring& message);
    void hide();
    bool isVisible() const { return window_ && IsWindowVisible(window_); }
    // receives an absolute index into EngineResult::allCandidates
    void setSelectionCallback(std::function<void(size_t)> callback) { select_ = std::move(callback); }

private:
    static bool ensureWindowClass();
    static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam);
    LRESULT handleMessage(UINT message, WPARAM wparam, LPARAM lparam);
    void place(HWND owner, const RECT& textRect);
    void paint();
    void paintCandidates(HDC dc, const RECT& client);
    void paintMessage(HDC dc, const RECT& client);
    void paintExpanded(HDC dc, const RECT& client);
    void paintKey(HDC dc, int left, int rowTop, const std::wstring& key, bool highlighted);
    void paintIndicator(HDC dc, const RECT& client, int footerTop, int arrowLeft);
    void ensureWindow(HWND owner);
    void updateFonts(UINT dpi);
    void applySettings();
    void releaseFonts();
    SIZE measure();
    bool hasMorePages() const { return expanded_ && expandedFirstPage_ + expandedPageCount_ < pageCount_; }
    int scale(int value) const;

    HWND window_ = nullptr;
    HFONT candidateFont_ = nullptr;
    HFONT keyFont_ = nullptr;
    HFONT indicatorFont_ = nullptr;
    UINT dpi_ = USER_DEFAULT_SCREEN_DPI;
    int rowHeight_ = 0;
    int candidateFontSize_ = 12;
    // the size the current fonts were made at
    int fontPoints_ = 0;
    CandidatePalette palette_;

    std::vector<EngineCandidate> candidates_;
    size_t highlightedIndex_ = 0;
    size_t candidatesPerPage_ = 0;
    size_t page_ = 0;
    size_t pageCount_ = 0;
    std::wstring message_;
    bool horizontal_ = false;
    bool expanded_ = false;
    size_t firstIndex_ = 0;
    size_t expandedFirstPage_ = 0;
    size_t expandedPageCount_ = 0;
    std::vector<std::wstring> allCandidates_;
    HFONT hintFont_ = nullptr;
    std::vector<RECT> candidateRects_;
    // absolute candidate index of each rect
    std::vector<size_t> rectIndexes_;
    std::function<void(size_t)> select_;
};

}  // namespace ChiaKey::WindowsTsf
