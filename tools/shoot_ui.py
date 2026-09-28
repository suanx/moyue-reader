#!/usr/bin/env python3
"""把 ui_mockup.html 渲染成效果图。

输出：
  墨阅UI总览.png        六屏拼版
  单页/*.png            每屏独立高清图（390x844 @2x）
"""
import asyncio
import os

from playwright.async_api import async_playwright

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = "file://" + os.path.join(BASE, "tools", "ui_mockup.html")
OUT = os.path.join(BASE, "效果图")
os.makedirs(OUT, exist_ok=True)

SINGLE = {
    "1 发现页": 1,
    "2 书架页": 2,
    "3 阅读页-竖排米黄": 3,
    "4 听书面板": 4,
    "5 AI中心": 5,
    "6 阅读页-横排夜间": 6,
}


async def main():
    async with async_playwright() as p:
        # 沙盒里 playwright 自带的 headless shell 未下载，直接用系统 chromium
        exe = next(
            (c for c in ("/usr/local/bin/chromium", "/usr/bin/google-chrome",
                         "/usr/bin/chromium") if os.path.exists(c)),
            None,
        )
        browser = await p.chromium.launch(
            executable_path=exe,
            args=["--no-sandbox", "--disable-dev-shm-usage", "--font-render-hinting=none"],
        )

        # --- 总览 ---
        page = await browser.new_page(viewport={"width": 1180, "height": 900},
                                      device_scale_factor=2)
        await page.goto(HTML, wait_until="networkidle")
        await page.wait_for_timeout(500)
        await page.screenshot(path=os.path.join(OUT, "墨阅UI总览.png"), full_page=True)
        print("✓ 墨阅UI总览.png")

        # --- 单屏 ---
        for name, idx in SINGLE.items():
            el = page.locator(f"figure:nth-child({idx}) .phone")
            await el.screenshot(path=os.path.join(OUT, f"{name}.png"))
            print(f"✓ {name}.png")

        await browser.close()


if __name__ == "__main__":
    asyncio.run(main())
