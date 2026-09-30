from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0003_hub_access_control"),
    ]

    operations = [
        migrations.AddField(
            model_name="message",
            name="attachment",
            field=models.FileField(
                blank=True,
                null=True,
                upload_to="chat_attachments/%Y/%m/",
            ),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_name",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="message",
            name="attachment_type",
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AlterField(
            model_name="message",
            name="body",
            field=models.TextField(blank=True),
        ),
    ]
