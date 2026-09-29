from rest_framework import permissions

from .models import Role


def _profile(request):
    return getattr(
        request.user,
        "profile",
        None,
    )


class IsAgent(permissions.BasePermission):
    def has_permission(self, request, view):
        profile = _profile(request)

        return bool(
            profile
            and profile.role == Role.AGENT
        )


class IsAdminOrAgent(permissions.BasePermission):
    def has_permission(self, request, view):
        profile = _profile(request)

        return bool(
            profile
            and profile.role in (
                Role.AGENT,
                Role.ADMIN,
            )
        )


class IsMemberOrAbove(permissions.BasePermission):
    def has_permission(self, request, view):
        profile = _profile(request)

        return bool(
            profile
            and profile.role in (
                Role.AGENT,
                Role.ADMIN,
                Role.MEMBER,
            )
        )


class ReadOnlyForVisitors(permissions.BasePermission):
    def has_permission(self, request, view):
        profile = _profile(request)

        if profile is None:
            return False

        if profile.role == Role.VISITOR:
            return request.method in permissions.SAFE_METHODS

        return True
