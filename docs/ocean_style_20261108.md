# FastRide ocean styling

Reference: SafeBoda’s public visual styling, adapted to FastRide with the user's
explicit ocean-blue preference. Brand identity, service behavior and account data
remain FastRide. Source reference: https://www.safeboda.com/home-ug and its public
stylesheet https://cdn.prod.website-files.com/630c89e33df16d6893e94a91/css/safeboda.webflow.shared.de9fd0fa6.css.

The public stylesheet names Asap; the font was obtained from the official Google
Fonts repository, not extracted from another app. Its SIL Open Font License is
in assets/fonts/Asap-OFL.txt and registered in the Flutter licences screen.

## Visual system

- Asap variable font with real 400/500/600/700/800 weights. All app-level text
  styles now use this family; body text is regular and headings have deliberate
  semibold/bold weights instead of displaying everything in a heavy font.
- Primary ocean blue #007EA7, deep blue #00617F, aqua #16B4C7, navy #123542,
  pale background #F2FAFC and white cards. Primary white button text contrast is
  approximately 4.62:1; secondary text uses a darker slate for readability.
- Cleaner cards and navigation indicators, soft aqua surfaces, readable dark
  banner copy. In-app logo tint, splash, dialogs and forms use the same palette.
- All service/vehicle art is cartoon artwork. The user subsequently requested
  original image colours: active assets now use illustrated_ filenames, with
  neutral banner overlays. Uploaded photos remain unchanged. Ocean recolours are
  retained on disk but excluded from the app bundle.
- Banners decode at a device-appropriate width, up to 2048 pixels, with high
  filtering quality; source scenes are about 1.6K wide and vehicle images 1536px.
  The illustrations are not photographs and no claim of additional detail from
  artificial upscaling is made.

## Earlier ocean artwork and prompts (unused alternatives)

Built-in image generation/editing was used. Assets:

- assets/branding/ocean_hero.png
- assets/branding/ocean_bus.png
- assets/branding/ocean_van.png
- assets/branding/ocean_local.png
- assets/vehicles/ocean_car.png
- assets/vehicles/ocean_motorcycle.png
- assets/vehicles/ocean_van.png
- assets/vehicles/ocean_bus.png
- assets/vehicles/ocean_tuktuk.png
- assets/vehicles/ocean_bicycle.png

Scene edit prompt: replace orange clothes, helmets, vehicle accents and pattern
details with ocean blue #007EA7 and teal-blue #16B4C7; replace cream background
with pale aqua #F2FAFC, brown outlines with navy #123542 and city elements with
muted grey-blue. Preserve composition, faces, poses, 2D cartoon drawing and crisp
contours. Keep natural skin tones unchanged. No logos, text or photographic people.

Vehicle edit prompt, applied separately to each listed vehicle: keep its type,
whole vehicle, three-quarter angle and centered white background. Rework bright
toy-like gradients into clean flat editorial 2D cartoon styling with ocean blue
#007EA7 accents, marine navy #123542, charcoal wheels/body, pale cyan windows
and small teal #16B4C7 details. Restrained shading, crisp contour, generous white
margin, no photographic or realistic 3D surfaces, no people, text or logos.

No new database migration is required for this visual update. The earlier shared
driver application migration remains necessary for application saving/approval.
