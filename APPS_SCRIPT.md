## Google Apps Script Web App for Onboarding

Use this script to append `{name, gender, age}` to the sheet with ID `1Z0URLeBJYlgwgJa41gA7K1_IED1Zp95cmCWyYf0-5rrtNlCvxEnetXU7`.

1) Go to https://script.google.com and create a new project under the `kishan.builds` account.  
2) Replace the default code with:
```javascript
const SHEET_ID = '1Z0URLeBJYlgwgJa41gA7K1_IED1Zp95cmCWyYf0-5rrtNlCvxEnetXU7';
const SHEET_NAME = 'Sheet1'; // change if your sheet tab has a different name

// Handle GET requests (for testing/debugging)
function doGet(e) {
  return ContentService
    .createTextOutput(JSON.stringify({ 
      status: 'ok', 
      message: 'Web app is running. Use POST to submit data.',
      endpoint: 'POST to this URL with JSON body: {name, gender, age}'
    }))
    .setMimeType(ContentService.MimeType.JSON);
}

// Handle POST requests (from iOS app)
function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    const ss = SpreadsheetApp.openById(SHEET_ID);
    const sheet = ss.getSheetByName(SHEET_NAME) || ss.getActiveSheet();
    // Column order: Name (A), Age (B), Gender (C), "what they are doing?" (D - empty for now)
    sheet.appendRow([
      body.name || '',      // Column A: Name
      body.age || '',       // Column B: Age
      body.gender || '',    // Column C: Gender
      ''                    // Column D: "what they are doing?" (not collected yet)
    ]);
    return ContentService
      .createTextOutput(JSON.stringify({ status: 'ok' }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: 'error', message: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
```
3) Deploy → New deployment → type **Web app** → Execute as **Me** → Who has access **Anyone** → Deploy.  
4) Copy the `/exec` URL and set it in `AppConfig.appsScriptEndpoint`.

