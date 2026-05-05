# Bug: Lead Creation Fails on Invalid Email

## What's happening

When you submit the Unknown Caller form with an invalid email (e.g. `"test"`), the server
throws a `ValidationError` and the lead is never created.

**Root cause — traceback summary:**

```
create_lead_with_note
  └─ lead.insert(ignore_permissions=True)
       └─ before_insert hook (ERPNext built-in)
            └─ lead.create_contact()        ← ERPNext always creates a Contact when inserting a Lead
                 └─ contact.insert()
                      └─ _validate_data_fields()
                           └─ validate_email_address("test", throw=True)
                                └─ ❌ InvalidEmailAddressError: "test" is not a valid Email Address
```

ERPNext's `Lead.before_insert` **automatically creates a linked Contact** for every new lead.
That Contact document inherits the `email_id` from the Lead.
Frappe's Contact validation then rejects any string that isn't a properly formed email address.

Because our `api.py` passed `email_id` straight through from the request without checking it,
a blank or garbage string reaches ERPNext's validator and blows up the whole insert.

## The fix

**In `api.py` → `create_lead_with_note`:** validate the email with
`frappe.utils.validate_email_address(email, throw=False)` before assigning it.
If the result is falsy (invalid or blank), set `email_id = None` so the field is
simply omitted — the Lead (and its auto-created Contact) inserts cleanly without it.

```python
# Before fix
lead = frappe.get_doc({
    "doctype":    "Lead",
    "first_name": first_name,
    "email_id":   email_id,      # ← could be "test", "", etc.
    ...
})

# After fix
from frappe.utils import validate_email_address
safe_email = validate_email_address(email_id or "", throw=False) or None

lead = frappe.get_doc({
    "doctype":    "Lead",
    "first_name": first_name,
    "email_id":   safe_email,    # ← None if invalid; ERPNext skips the field
    ...
})
```

Same guard is applied to the `existing_lead` duplicate-check query so a garbage
email doesn't accidentally match an unrelated lead.
