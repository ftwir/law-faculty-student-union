import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.utils.text import slugify

from core.models import Hub, HubMembership, HubMembershipRole, Role, User


class Command(BaseCommand):
    help = "Create or update the initial Agent account and bootstrap the default community."

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

        profile, _ = User.objects.get_or_create(
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

        # Bootstrap the five fixed faculty hubs.
        # Every hub is private: members must request access and be approved
        # by that hub's administrator.
        hub_specs = [
            (
                "عام - جميع السنوات",
                "general",
                "القسم العام لجميع طلبة كلية القانون.",
            ),
            (
                "السنة الأولى",
                "year-1",
                "مجتمع طلبة السنة الأولى.",
            ),
            (
                "السنة الثانية",
                "year-2",
                "مجتمع طلبة السنة الثانية.",
            ),
            (
                "السنة الثالثة",
                "year-3",
                "مجتمع طلبة السنة الثالثة.",
            ),
            (
                "السنة الرابعة",
                "year-4",
                "مجتمع طلبة السنة الرابعة.",
            ),
        ]

        existing_hubs = list(Hub.objects.order_by("id"))

        # Convert the old single default hub into the new general hub.
        if existing_hubs:
            general = existing_hubs[0]
            general.name = hub_specs[0][0]
            general.slug = hub_specs[0][1]
            general.description = hub_specs[0][2]
            general.is_public = False
            general.hub_admin = profile
            general.save()
        else:
            general = Hub.objects.create(
                name=hub_specs[0][0],
                slug=hub_specs[0][1],
                description=hub_specs[0][2],
                is_public=False,
                created_by=profile,
                hub_admin=profile,
            )

        HubMembership.objects.update_or_create(
            hub=general,
            user=profile,
            defaults={
                "role": HubMembershipRole.LEADER,
                "status": "approved",
            },
        )

        for name, slug, description in hub_specs[1:]:
            hub, _ = Hub.objects.get_or_create(
                slug=slug,
                defaults={
                    "name": name,
                    "description": description,
                    "is_public": False,
                    "created_by": profile,
                    "hub_admin": profile,
                },
            )
            hub.name = name
            hub.description = description
            hub.is_public = False
            if hub.hub_admin_id is None:
                hub.hub_admin = profile
            hub.save(update_fields=["name", "description", "is_public", "hub_admin"])

        self.stdout.write(
            self.style.SUCCESS(
                "Default hub structure ready: general + years 1-4."
            )
        )

        action = "created" if created else "updated"
        self.stdout.write(
            self.style.SUCCESS(
                f"Initial Agent account {action}: {username}"
            )
        )
