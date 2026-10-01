from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0004_message_attachments"),
    ]

    operations = [
        migrations.AlterField(
            model_name="quizquestion",
            name="options",
            field=models.JSONField(help_text="List of option strings"),
        ),
    ]
