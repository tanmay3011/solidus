$ ->
  ($ '#new_image_link').click (event) ->
    event.preventDefault()

    ($ '.no-objects-found').hide()

    ($ this).hide()
    Spree.ajax
      type: 'GET'
      url: @href
      data: (
        authenticity_token: AUTH_TOKEN
      )
      success: (r) ->
        ($ '#images').html r
        ($ '.select2').select2()
