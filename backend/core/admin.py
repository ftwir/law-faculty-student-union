from django.contrib import admin

from . import models


admin.site.register(models.User)
admin.site.register(models.AdminPermissionGrant)

admin.site.register(models.Hub)
admin.site.register(models.HubMembership)

admin.site.register(models.Post)
admin.site.register(models.Comment)

admin.site.register(models.Poll)
admin.site.register(models.PollOption)
admin.site.register(models.PollVote)

admin.site.register(models.Quiz)
admin.site.register(models.QuizQuestion)
admin.site.register(models.QuizAttempt)

admin.site.register(models.Flashcard)

admin.site.register(models.ChatRoom)
admin.site.register(models.ChatParticipant)
admin.site.register(models.Message)

admin.site.register(models.Badge)
admin.site.register(models.UserBadge)

admin.site.register(models.Notification)
