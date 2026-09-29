from rest_framework import permissions

from .models import Role


def _profile(request):
    return getattr(request.user, "profile", None)


class IsAgent(permissions.BasePermission):
    """Only the single super-admin (Agent) may pass."""

    def has_permission(self, request, view):
        profile = _profile(request)
        return bool(profile and profile.role == Role.AGENT)


class IsAdminOrAgent(permissions.BasePermission):
    """Union Board administrators and the Agent."""

    def has_permission(self, request, view):
        profile = _profile(request)
        return bool(profile and profile.role in (Role.AGENT, Role.ADMIN))


class IsMemberOrAbove(permissions.BasePermission):
    """Registered students, admins, and the agent — excludes Visitors."""

    def has_permission(self, request, view):
        profile = _profile(request)
        return bool(profile and profile.role in (Role.AGENT, Role.ADMIN, Role.MEMBER))


class ReadOnlyForVisitors(permissions.BasePermission):
    """Visitors get read-only (GET/HEAD/OPTIONS); everyone else full access."""

    def has_permission(self, request, view):
        profile = _profile(request)
        if not profile:
            return False
        if profile.role == Role.VISITOR:
            return request.method in permissions.SAFE_METHODS
        return True
