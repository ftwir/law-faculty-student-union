import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from core.models import Role, User


class Command(BaseCommand):
    help = "Create or update the initial Agent account from environment variables."

    def handle(self, *args, **options):
        username = os.environ.get("INITIAL_AGENT_USERNAME")
        password = os.environ.get("INITIAL_AGENT_PASSWORD")
        student_id = os.environ.get("INITIAL_AGENT_STUDENT_ID", "")
        display_name = os.environ.get(
            "INITIAL_AGENT_DISPLAY_NAME",
            "Law Faculty Student Union Agent",
        )

        if not username:
            raise CommandError("INITIAL_AGENT_USERNAME is not configured.")

        if not password:
            raise CommandError("INITIAL_AGENT_PASSWORD is not configured.")

        DjangoUser = get_user_model()

        django_user, created = DjangoUser.objects.get_or_create(
            username=username,
            defaults={
                "is_active": True,
                "is_staff": True,
            },
        )

        django_user.is_active = True
        django_user.is_staff = True
        django_user.set_password(password)
        django_user.save()

        profile, profile_created = User.objects.get_or_create(
            user=django_user,
            defaults={
                "student_id": student_id or None,
                "display_name": display_name,
                "role": Role.AGENT,
            },
        )

        profile.role = Role.AGENT
        profile.display_name = display_name

        if student_id:
            profile.student_id = student_id

        profile.save()

        action = "created" if created else "updated"

        self.stdout.write(
            self.style.SUCCESS(
                f"Initial Agent account {action}: {username}"
            )
        )
