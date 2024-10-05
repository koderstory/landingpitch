from django.db import models
from wagtail.admin.panels import FieldPanel
from wagtail.fields import RichTextField
from wagtail.models import Page

# Create your models here.
class BlankPage(Page):
    template = 'landingpitch/blankpage.html'

class BlogPage(Page):
    template = 'landingpitch/blogpage.html'

class PostPage(Page):
    body = RichTextField(blank=True)
    created = models.DateTimeField(auto_now_add=True)
    updated = models.DateTimeField(auto_now=True)

    content_panels = Page.content_panels + [
        FieldPanel('body'),
    ]

    template = 'landingpitch/postpage.html'

