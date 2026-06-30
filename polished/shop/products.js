/* ============================================================================
   BLACK SILVA — SHOP PRODUCTS
   ----------------------------------------------------------------------------
   HOW TO USE (no coding needed):

   1) PHOTOS — put your product photos in THIS "shop" folder, next to this file.
      Name them image1, image2, image3 ... (jpg, png or webp all work).
        shop/image1.jpg
        shop/image2.jpg

   2) For each product below, fill in:
        img   = the photo file name (e.g. 'shop/image1.jpg')  — leave '' for none
        name  = the product name
        price = the price text (e.g. '150 DKK')   — change this to update a price
        desc  = the full description (shown when a product is tapped)
        soon  = true  -> shows a "Coming soon" card (no price/photo needed)

   3) Products show on the website in the SAME ORDER as the list below.
        - To ADD a product: copy a block and change it.
        - To REMOVE a product: delete its block.
   ============================================================================ */
window.SHOP_PRODUCTS = [
  {
    img: 'shop/image1.jpg',
    name: 'Barba Italiana — Fenice',
    price: '150 DKK',
    desc: 'Fenice is an effective shampoo against all types of dandruff.\n\n'
        + 'The combination of Piroctone Olamine and Zinc PCA — known for their antifungal and antibacterial properties — along with essential oils of lavender, rosemary, pine and lemon, helps fight and prevent dandruff.\n\n'
        + 'The cleansing and balancing properties of the essential oils work on both oily and dry hair, helping to restore the scalp’s natural balance.\n\n'
        + 'Not tested on animals. Free from paraffin, SLS, SLES, silicone and their derivatives.'
  },
  {
    img: 'shop/image2.jpg',
    name: 'Barba Italiana — Nabucco (250 ml)',
    price: '150 DKK',
    desc: 'Soothing shampoo for sensitive scalp.\n\n'
        + 'Nabucco relieves itching, redness and dandruff. Thanks to the soothing properties of essential oils of fennel, myrtle and lavender, this shampoo is ideal for reducing discomfort on an irritated scalp and restoring its optimal health.\n\n'
        + 'Not tested on animals. Free from paraffin, SLS, SLES, silicone and their derivatives.'
  },
  { soon: true },
  { soon: true },
  { soon: true },
  { soon: true }
];
