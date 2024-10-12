from datetime import datetime

from django.conf import settings
from django.core.paginator import Paginator, PageNotAnInteger, EmptyPage
from django.db import models
from modelcluster.contrib.taggit import ClusterTaggableManager
from modelcluster.fields import ParentalKey
from taggit.models import TaggedItemBase
from wagtail.admin.panels import FieldPanel
from wagtail.blocks import StreamBlock, StructBlock
from wagtail.fields import RichTextField, StreamField
from wagtail.models import Page


# Create your models here.


class HeroBlock(StructBlock):
    class Meta:
        template = 'landingpitch/blocks/hero.html'

class SectionBlock(StructBlock):
    class Meta:
        template = 'landingpitch/blocks/section.html'



class BlankPage(Page):

    body = StreamField([
        ('hero', HeroBlock()),
        ('section', SectionBlock()),
    ], null=True, blank=True)

    template = 'landingpitch/blankpage.html'

    content_panels = Page.content_panels + [
        FieldPanel('body'),
    ]


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

        # Pagination: Show 5 posts per page
        paginator = Paginator(postpages, 2)  # Show 5 posts per page

        # Get the page number from the query string (GET parameter)
        page = request.GET.get('page')

        try:
            postpages = paginator.page(page)
        except PageNotAnInteger:
            # If the page number is not an integer, show the first page
            postpages = paginator.page(1)
        except EmptyPage:
            # If the page number is out of range, show the last page
            postpages = paginator.page(paginator.num_pages)

        # Add paginated posts to the context
        context['postpages'] = postpages
        return context


class PostPage(Page):
    short = RichTextField(blank=True)
    body = RichTextField(blank=True)
    created = models.DateTimeField(auto_now_add=True)
    updated = models.DateTimeField(auto_now=True)
    featured_image = models.ForeignKey('wagtailimages.Image', on_delete=models.SET_NULL, related_name='+', blank=True, null=True, )

    tags = ClusterTaggableManager(through="PostPageTag", blank=True)

    content_panels = Page.content_panels + [
        FieldPanel('body'),
        FieldPanel('tags'),
        FieldPanel('short'),
        FieldPanel('featured_image'),
    ]

    template = 'landingpitch/postpage.html'


class BlogPageWithTag(Page):
    template = 'landingpitch/blogpage_with_tag.html'

    def get_context(self, request):
        # Filter by tag
        tag = request.GET.get('tag')
        postpages = PostPage.objects.filter(tags__name=tag)

        # Update template context
        context = super().get_context(request)
        context['postpages'] = postpages
        return context


class PostPageTag(TaggedItemBase):
    content_object = ParentalKey(
        'PostPage',
        related_name='tagged_items',
        on_delete=models.CASCADE,
    )
