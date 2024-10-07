from datetime import datetime

from django.conf import settings
from django.db import models
from wagtail.admin.panels import FieldPanel
from wagtail.fields import RichTextField
from wagtail.models import Page

# Create your models here.
class BlankPage(Page):
    template = 'landingpitch/blankpage.html'

class BlogPage(Page):
    intro = RichTextField(blank=True)

    content_panels = Page.content_panels + [
        FieldPanel('intro')
    ]

    template = 'landingpitch/blogpage.html'

    def get_context(self, request):
        # Update context to include only published posts, ordered by reverse-chron
        context = super().get_context(request)
        postpages = self.get_children().live().order_by('-first_published_at')
        context['postpages'] = postpages
        return context

class PostPage(Page):
    short = RichTextField(blank=True)
    body = RichTextField(blank=True)
    created = models.DateTimeField(auto_now_add=True)
    updated = models.DateTimeField(auto_now=True)

    content_panels = Page.content_panels + [
        FieldPanel('body'),
        FieldPanel('short'),
    ]

    template = 'landingpitch/postpage.html'
