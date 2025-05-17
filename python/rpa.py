from playwright.sync_api import sync_playwright
from playwright.sync_api import BrowserContext
import pyotp
import logging

logger = logging.getLogger("athena_reports_scraper")
if isinstance(username, bytes):
    username = username.decode('utf-8')
if isinstance(password, bytes):
    password = password.decode('utf-8')
if isinstance(totp_secret, bytes):
    totp_secret = totp_secret.decode('utf-8')
if isinstance(patient_id, bytes):
    patient_id = patient_id.decode('utf-8')
if isinstance(note_content, bytes):
    note_content = note_content.decode('utf-8')
if isinstance(base_url, bytes):
    base_url = base_url.decode('utf-8')

def submit_patient_note(username: str, password: str, totp_secret: str, patient_id: str, note_content: str, base_url: str):
    with sync_playwright() as p:
        browser = p.chromium.launch(
            args=["--disable-gpu", "--single-process"], headless=False
        )
        browser_context = browser.new_context()

        patient_note_handler(username, password, totp_secret, patient_id, note_content, base_url, browser_context)

        browser_context.close()
        browser.close()
        return "ok"

def patient_note_handler(username: str, password: str, totp_secret: str, patient_id: str, note_content: str, base_url: str, context: BrowserContext, clinic_id: int = None):
    athena_url = base_url
    page = context.new_page()
    page.set_default_timeout(120000)
    page.set_default_navigation_timeout(120000)
    page.goto(athena_url)

    page.fill("input[id*=athena-username], input[id*=USERNAME]", username)
    page.fill("input[id*=athena-password], input[id*=PASSWORD]", password)
    page.click("#athena-o-form-button-bar > div > div > button, input[id*=loginbutton]")
    # If 2FA is enabled, fill the TOTP
    if totp_secret:
        page.wait_for_url("**/oauth2/**", wait_until="domcontentloaded")
        page.fill("input#athena-answer", pyotp.TOTP(totp_secret).now())
        page.click("div#athena-o-form-button-bar")
    # Pracitce ID selection
    if clinic_id:
        page.wait_for_url(url="**/login/oidc.esp")
        page.wait_for_selector("select#PRACTICEID").select_option(value=clinic_id)
        page.click("input#loginbutton")

    # Navigate to the reports library
    page.wait_for_url(url="**/choosedepartment.esp", wait_until="domcontentloaded")
    page.click("input#loginbutton")

    page.wait_for_url(url="**/globalframeset.esp**", wait_until="domcontentloaded")
    elements = page.query_selector_all("._pendo-close-guide")
    if elements:
        elements[0].click()
    iframe = page.query_selector("iframe#GlobalNav")
    if iframe:
        frame = iframe.content_frame()
        frame.wait_for_load_state("networkidle")

        search_menu = frame.wait_for_selector("input#searchinput")
        page.wait_for_event("load")

        search_menu.click()
        search_menu.type(patient_id, delay=200)
        search_menu.click()

        page.keyboard.press("Enter")

        fill_patient_note(page, note_content)

    else:
        logger.error("iframe#GlobalNav not found")
        raise Exception("iframe#GlobalNav not found")
    try: 
        fill_patient_note(page, note_content)
    except Exception as e:
        logger.error(f"Error: {e}")
        raise Exception(f"Error: {e}")

def fill_patient_note(page, note_content):
    try:
        iframe_global_wrapper = page.wait_for_selector("iframe#GlobalWrapper")
        frame_global_wrapper = iframe_global_wrapper.content_frame()

        iframe_frameContent = frame_global_wrapper.wait_for_selector("frame#frameContent")
        frame_frameContent = iframe_frameContent.content_frame()

        iframe = frame_frameContent.wait_for_selector("iframe#frMain")
        frame = iframe.content_frame()
        frame.wait_for_load_state(state="networkidle")

        page.wait_for_timeout(1000)
        notes_element = frame.wait_for_selector("textarea[name='NOTES']")
        from datetime import datetime
        current_content = notes_element.input_value()
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        notes_element.fill(current_content + "\n" + timestamp + ": " + note_content)
        page.wait_for_timeout(1000)
        frame.wait_for_selector("input#savechanges").click()
    except Exception as e:
        raise Exception(f"Error: {e}")
    page.wait_for_timeout(2000)


submit_patient_note(username, password, totp_secret, patient_id, note_content, base_url)
