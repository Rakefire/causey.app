const setupAsyncForms = () => {
  Array
    .from(document.querySelectorAll("form[data-type='async-form']"))
    .forEach(form => {
      // Override the submit event
      form.addEventListener("submit", event => {
        event.preventDefault()

        // TODO add Goolge Captcha
        // if (grecaptcha) {
        //   var recaptchaResponse = grecaptcha.getResponse()
        //   if (!recaptchaResponse) { // reCAPTCHA not clicked yet
        //     return false
        //   }
        // }

        const formData = new FormData(form)

        fetch(form.action, {
          method: form.method,
          redirect: 'manual', // this is to not follow redirects
          body: formData // directly pass the FormData object
        })
          .then(response => {
            if (response.type == "opaqueredirect" && response.url.endsWith(form.action)) {
              return response.text()
            } else {
              throw new Error(`Request failed with status: ${response.status}`)
            }
          })
          .then(_ => {
            const successMessage = form.querySelector("[name='_success_message']")?.value || "Success! Please check your email for the resource!"
            form.innerHTML = `<p>${successMessage}</p>`
          })
          .catch(_ => {
            const failureMessage = form.querySelector("[name='_failure_message']")?.value || "I'm sorry, something didn't work. Please refresh and try again."
            form.innerHTML = `<p>${failureMessage}</p>`
          })
      })
    })
}

document.addEventListener("DOMContentLoaded", setupAsyncForms)