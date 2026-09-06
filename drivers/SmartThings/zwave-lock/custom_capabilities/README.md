# Schlage custom capabilities

These JSON files define the custom capabilities used by the Schlage profiles.
They must be created in the `heartsample19211` SmartThings namespace before
packaging this driver, followed by their matching presentations.

The `lockActivity` capability replaces the Community driver's `unlockCodeName`.
It provides a display-only last-activity message and automation conditions for
the activity type and the manually entered user name.
