from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="bio",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="user",
            name="academic_year",
            field=models.CharField(max_length=32, blank=True),
        ),
        migrations.AddField(
            model_name="post",
            name="post_type",
            field=models.CharField(default="post", max_length=16),
        ),
        migrations.CreateModel(
            name="WikiPage",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=160)),
                ("slug", models.SlugField()),
                ("summary", models.TextField(blank=True)),
                ("content", models.TextField()),
                ("cover_image_url", models.URLField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("created_by", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="wiki_pages_created", to="core.user")),
                ("hub", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="wiki_pages", to="core.hub")),
                ("updated_by", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="wiki_pages_updated", to="core.user")),
            ],
            options={
                "ordering": ("-updated_at",),
                "unique_together": {("hub", "slug")},
            },
        ),
        migrations.CreateModel(
            name="ContentReport",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("reason", models.TextField()),
                ("status", models.CharField(choices=[("open", "Open"), ("reviewing", "Reviewing"), ("resolved", "Resolved"), ("dismissed", "Dismissed")], default="open", max_length=16)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("comment", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="reports", to="core.comment")),
                ("post", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="reports", to="core.post")),
                ("reporter", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reports_created", to="core.user")),
                ("resolved_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="reports_resolved", to="core.user")),
            ],
        ),
    ]
