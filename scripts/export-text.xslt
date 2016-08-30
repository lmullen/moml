<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text" encoding="UTF-8" omit-xml-declaration="yes" indent="no" media-type="text/csv" />

    <xsl:variable name="book_id" select="/book/bookInfo/documentID" />

    <xsl:template match="/">
        <xsl:for-each select="/book/text/page">
            <xsl:for-each select="./pageContent/p">
                <xsl:value-of select="$book_id" />
                <xsl:text>,</xsl:text>
                <xsl:value-of select="ancestor::page/pageInfo/pageID" />
                <xsl:text>,</xsl:text>
                <xsl:value-of select="position()" />
                <xsl:text>,</xsl:text>
                <xsl:variable name="current_text" select="normalize-space()" />
                <xsl:text>"</xsl:text>
                <xsl:value-of select="replace($current_text, '&quot;', '&quot;&quot;')" />
                <xsl:text>"</xsl:text>
                <xsl:text>&#xa;</xsl:text> <!-- line break -->
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>

</xsl:stylesheet>

