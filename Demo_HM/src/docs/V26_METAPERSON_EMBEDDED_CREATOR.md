# v26 MetaPerson Embedded Creator Fix

- MetaPerson no longer opens as forced full-screen modal.
- Creator stays embedded in the page so Persona Studio buttons remain clickable.
- Generate From Active Photo automatically reads the selected persona photo and sends base64 to MetaPerson.
- Re-auth/config messages are retried to avoid missed iframe load events.
- DevTools resize should not hide iframe content.
