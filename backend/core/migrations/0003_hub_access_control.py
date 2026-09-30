from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0002_community_features"),
    ]

    operations = [
        migrations.AddField(
            model_name="hub",
            name="hub_admin",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="managed_hubs",
                to="core.user",
            ),
        ),
        migrations.AddField(
            model_name="hubmembership",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("approved", "Approved"),
                    ("rejected", "Rejected"),
                ],
                default="pending",
                max_length=16,
            ),
        ),
        migrations.AlterField(
            model_name="hub",
            name="is_public",
            field=models.BooleanField(default=False),
        ),
    ]
