from django.db import models
from wagtail.models import Page

# Create your models here.
class BlankPage(Page):
    template = 'landingpitch/blankpage.html'

class BlogPage(Page):
    template = 'landingpitch/blogpage.html'

class PostPage(Page):
    template = 'landingpitch/postpage.html'

