# Generated by Django 5.1.1 on 2024-10-13 01:13

import wagtail.fields
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('landingpitch', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='blankpage',
            name='body',
            field=wagtail.fields.StreamField([('hero', 1), ('section', 2)], blank=True, block_lookup={0: ('wagtail.blocks.RichTextBlock', (), {'blank': True, 'null': True}), 1: ('wagtail.blocks.StructBlock', [[('content', 0)]], {}), 2: ('wagtail.blocks.StructBlock', [[]], {})}, null=True),
        ),
    ]
