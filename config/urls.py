from django.contrib import admin
from django.urls import path, include, re_path
from django.views.generic import TemplateView
from django.conf import settings
from django.conf.urls.static import static

from wagtail import urls as wagtail_urls
from wagtail.admin import urls as wagtailadmin_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    path('examples/post', TemplateView.as_view(template_name='snippets/pages/postpage.html')),


    path('dashboard/', admin.site.urls),
    path('web/', include(wagtailadmin_urls)),
    path('documents/', include(wagtaildocs_urls)),

    # Optional URL for including your own vanilla Django urls/views
    re_path(r'', include('landingpitch.urls')),

    # For anything not caught by a more specific rule above, hand over to
    # Wagtail's serving mechanism
    re_path(r'', include(wagtail_urls)),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)