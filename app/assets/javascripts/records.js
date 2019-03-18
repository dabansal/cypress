/*global Turbolinks */

var ready;
ready = function() {
  // when the user selects a different bundle
  // just take them to the new page
  // use Turbolinks so it doesn't full refresh
  $('label.bundle-checkbox input[name="bundle_id"]').on('change', function() {
    var bundle_id = $(this).val();
    Turbolinks.visit("/bundles/"+bundle_id+"/records");
  });
  $('label.vendor-checkbox input[name="bundle_id"]').on('change', function() {
    var bundle_id = $(this).val();
    Turbolinks.visit("?bundle_id="+bundle_id);
  });
}

$(document).ready(ready);
$(document).on('page:load', ready);
