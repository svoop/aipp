# LF – France Mainland

## Prerequisites

This parser requires the XML data dump from SIA. It is available free of charge, but has to be ordered before it can be downloaded. It's therefore necessary to perform the following steps before running the parser for any given AIRAC for the first time:

1. Browse to the [SIA web shop](https://www.sia.aviation-civile.gouv.fr/produits-numeriques-en-libre-disposition/les-bases-de-donnees-sia.html).
2. Shop the desired dump named «données aéronautiques XML AIRAC ii/yy».
3. Browse to [your customer page](https://www.sia.aviation-civile.gouv.fr/customer/account/#orders-and-proposals).
4. On page «mes produits téléchargeables» download the desired dump.
5. Unzip the downloaded ZIP archive.
6. Move the file «XML_SIA_yyyy-mm-dd.xml» to the directory in which you will execute the parser.

⚠️ The SIA web shop misbehaves with some browsers, you should try Brave or Chrome.

## Region Options

### Obstacles XLSX

While the XML data dump contains all obstacles, some details of the source XLSX file are omitted. Unfortunately, the latter is only available for the current AIRAC cycle, therefore the XML data dump is used by default. Add `-o lf_obstacles_xlsx` to use the source XLSX file instead.

## Charset

The XML data dump from SIA is ISO-8859-1 encoded. Nokogiri which parses the XML converts this to UTF-8 on the fly, however, when grepping the dump on a shell, you might run into trouble:

```shell
grep "<Revetement>" XML_SIA_2021-12-02.xml | sort | uniq

sort: Illegal byte sequence
```

For this to work, you have to convert the dump to UTF-8 and use this converted dump for grepping:

```shell
iconv -f ISO-8859-1 -t UTF-8 XML_SIA_2021-12-02.xml >XML_SIA_2021-12-02_UTF.xml
grep "<Revetement>" XML_SIA_2021-12-02_UTF.xml | sort | uniq

<Revetement>Aluminium</Revetement>
<Revetement>Asphalte</Revetement>
<Revetement>Béton ( 4t )</Revetement>
(...)
```

## References

* [SIA – AIP publisher](https://www.sia.aviation-civile.gouv.fr)
* [SIA XML usage guide](https://www.sia.aviation-civile.gouv.fr/faqs)
* [OpenData – public data files](https://www.data.gouv.fr)
* [Protected Planet – protected area data files](https://www.protectedplanet.net)
