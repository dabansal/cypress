$(document).on('page:change', function(event) {
  // reinitialize parsley on turbolinks page:change
  var $forms = $('form[data-parsley-validate]');

  if ($forms.length > 0) {
    $forms.parsley().on('field:validate', function (fieldInstance) {
      // enable the submit button if form is valid
      var formIsValid = fieldInstance.parent.$element.parsley().isValid();
      $('.btn[type="submit"]').attr('disabled', !formIsValid);
    });
  }
});


$(function() {
  // add custom validation for password field
  window.Parsley
    .addValidator('passwordcomplexity', {
      requirementType: 'regexp',
      validateString: function(value, requirement) {
        var matches = 0;
        [/\d/, /[A-Z]/, /[a-z]/, /[\W]/].forEach(function(pattern){
          if (value.match(pattern)) { matches++ };
        });
        return (matches >= 3) ? true : false;
      },
      messages: {
        en: 'Does not have at least 3 of the specified character types.',
      }
    });
});