/// Minúsculas y sin tildes, para que "catalogo" encuentre "Catálogo".
String foldSearch(String v) {
  const String from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const String to = 'aaaaeeeeiiiioooouuuun';
  final StringBuffer b = StringBuffer();
  for (final int r in v.toLowerCase().runes) {
    final String ch = String.fromCharCode(r);
    final int i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().trim();
}
