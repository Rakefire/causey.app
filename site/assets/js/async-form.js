// Helper function to get form data in the supported format
const getFormDataString = formEl => {
  let formData = new FormData(formEl);
  let data = [];

  for (var keyValue of formData) {
    data.push(encodeURIComponent(keyValue[0]) + "=" + encodeURIComponent(keyValue[1]));
  }

  return data.join("&");
};

const setupAsyncForms = () => {
  Array
    .from(document.querySelectorAll("form[data-type='async-form']"))
    .forEach(form => {
      // Override the submit event
      form.addEventListener("submit", event => {
        event.preventDefault();

        // TODO add Goolge Captcha
        // if (grecaptcha) {
        //   var recaptchaResponse = grecaptcha.getResponse()
        //   if (!recaptchaResponse) { // reCAPTCHA not clicked yet
        //     return false
        //   }
        // }

        var request = new XMLHttpRequest();

        request.addEventListener("load", () => {
          if (request.status === 302 || request.status === 303 || request.status === 200) { // CloudCannon redirects on success
            const successMessage = form.querySelector("[name='_success_message']")?.value || "Success! Please check your email for the resource!";

            form.innerHTML = `<p>${successMessage}</p>`;
          } else {
            const failureMessage = form.querySelector("[name='_failure_message']")?.value || "I'm sorry, something didn't work. Please refresh and try again.";
            form.innerHTML = `<p>${failureMessage}</p>`;
          }
        });

        request.open(form.method, form.action);
        request.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        request.send(getFormDataString(form));
      });
    });
};

document.addEventListener("DOMContentLoaded", setupAsyncForms);